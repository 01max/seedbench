require 'rails_helper'

RSpec.describe Release do
  let(:release) { build_release_graph }

  it 'persists independent revisions, evidence, review decisions and provider identities', :aggregate_failures do
    expect(release.reload.payload_revisions.sole.sha256).to eq('a' * 64)
    expect(release.reviewed_facts.sole.value).to eq('Synthetic book')
    expect(release.fact_evidence_links.sole.evidence_item.evidence_key).to eq('synthetic-title-page')
    expect(release.finding_acknowledgements.sole.finding.severity).to eq('uncertainty')
    expect(release.content_revisions.sole.body).to eq('Human text')
    expect(release.cover_hostings.sole.cover_revision.number).to eq(1)
    expect(release.duplicate_decisions.sole.reason).to eq('Different edition')
    expect(release.remote_snapshots.sole.base_content).to eq('body' => 'base')
    expect(release.ai_runs.sole.evidence_keys).to eq([ 'synthetic-title-page' ])
    expect(release.provider_assignments.count).to eq(4)
  end

  it 'rejects cross-release references at the database boundary' do
    evidence = release.evidence_items.sole
    other = described_class.create!
    sql = <<~SQL.squish
      INSERT INTO evidence_items (release_id, payload_revision_id, evidence_key, kind, source, captured_at, input_revision, data, created_at, updated_at)
      SELECT #{other.id}, payload_revision_id, 'cross-release', kind, source, captured_at, input_revision, data, created_at, updated_at
      FROM evidence_items WHERE id = #{evidence.id}
    SQL

    expect { described_class.connection.execute(sql) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'rejects duplicate content revision identities' do
    content = release.content_revisions.sole

    expect { ContentRevision.create!(content.attributes.except('id', 'created_at', 'updated_at')) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'requires reasons for duplicate overrides' do
    check = release.duplicate_checks.sole

    expect do
      DuplicateDecision.create!(release: release, duplicate_check: check, candidate_key: 'another',
        decision: 'false_positive', actor: 'operator', reviewed_at: Time.current)
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it 'protects history against SQL updates and deletes', :aggregate_failures do
    event = release.release_events.sole

    expect { described_class.connection.execute("UPDATE release_events SET name = 'changed' WHERE id = #{event.id}") }
      .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    expect { described_class.connection.execute("DELETE FROM release_events WHERE id = #{event.id}") }
      .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
  end

  it 'retains the failing finding revision when a newer finding is added' do
    finding = release.findings.sole
    Finding.create!(finding.attributes.except('id', 'created_at', 'updated_at').merge(number: 2, message: 'New evidence'))

    expect(release.finding_acknowledgements.sole.finding.number).to eq(1)
    expect(release.findings.count).to eq(2)
  end

  it 'allows explicitly unconfigured provider roles but rejects role mismatches', :aggregate_failures do
    unconfigured = ProviderAssignment.create!(release: described_class.create!, role: 'publishing')
    expect(unconfigured.provider_connection).to be_nil
    connection = release.provider_assignments.find_by!(role: 'ai').provider_connection
    sql = "UPDATE provider_assignments SET provider_connection_id = #{connection.id} WHERE id = #{unconfigured.id}"

    expect { described_class.connection.execute(sql) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'enforces payload identity and supported formats' do
    payload = PayloadRevision.new(release: release, number: 2, original_filename: 'bad.exe', format: 'exe',
      size_bytes: 0, sha256: 'invalid', locator: 'staging/bad.exe')

    expect(payload).not_to be_valid
  end

  it 'keeps each workflow dimension independent' do
    record = described_class.create!(inspection_state: 'succeeded', preparation_state: 'unprepared')

    expect(record.publication_state).to eq('unpublished')
    expect(record.seeding_state).to eq('not_started')
    expect(record).to be_automatic_ai
  end
end
