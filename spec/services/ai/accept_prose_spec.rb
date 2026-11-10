require 'rails_helper'

RSpec.describe Ai::AcceptProse do
  let(:release) { reviewed_content_release }

  before { configure_ai(release) }

  def completed(purpose)
    run = Ai::Request.call(release_id: release.id, expected_revision: release.reload.input_revision, purpose: purpose)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: ai_response(ai_output(run.request['pack'], purpose: purpose)))
    Workflows::Execute.call(operation_id: run.workflow_operation_id)
    run.reload
  end

  def accept_prose(run, field: 'presentation')
    Ai::AcceptProse.call(release_id: release.id, run_id: run.id, field: field, expected_revision: release.reload.input_revision)
  end

  it 'changes only the accepted prose field, keeps human BBCode/NFO and records AI provenance exactly once' do
    run = completed('prose')
    before = Releases::EditorValues.call(release: release)
    2.times { accept_prose(run) }
    after = Releases::EditorValues.call(release: release.reload)
    expect(after.except('presentation')).to eq(before.except('presentation'))
    expect(after['presentation']).to eq(run.result.dig('output', 'presentation'))
    expect(release.content_revisions.where(origin: 'ai').sole.dependencies['ai_run_id']).to eq(run.id)
  end

  it 'preserves a newer human presentation and rejects forbidden targets and stale facts' do
    run = completed('prose')
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { presentation: 'Présentation humaine plus récente.' })
    expect { accept_prose(run) }.to raise_error(Ai::Failure, /conservé/)
    expect { accept_prose(run, field: 'nfo') }.to raise_error(Ai::Failure)
    expect(Releases::EditorValues.call(release: release.reload)['presentation']).to eq('Présentation humaine plus récente.')
  end

  it 'retains newer NFO edits while allowing explicit review of still-applicable prose' do
    run = completed('prose')
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { nfo: 'NFO humain à conserver' })
    accept_prose(run)
    expect(Releases::EditorValues.call(release: release.reload)['nfo']).to eq('NFO humain à conserver')
    proposal = Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'bbcode')
    expect(proposal.bodies['bbcode']).to include(run.result.dig('output', 'presentation'))
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq('Human text')
  end

  it 'adopts a source-supported fact only through human review with retained citations' do
    run = completed('assessment')
    original = release.reviewed_facts.count
    Ai::AcceptFact.call(release_id: release.id, run_id: run.id, candidate_index: 0, expected_revision: release.input_revision)
    fact = release.reviewed_facts.where(field: 'title').order(:number).last
    expect(release.reviewed_facts.count).to eq(original + 1)
    expect(fact.actor).to eq('operator')
    expect(fact.fact_evidence_links.sole.evidence_item.data['ai_run_id']).to eq(run.id)
    expect(run.reload.status).to eq('succeeded')
  end

  it 'rejects old fact suggestions after material changes without clearing a measured failure' do
    run = completed('assessment')
    failure = release.findings.create!(payload_revision: release.payload_revisions.sole, code: 'synthetic_failure', number: 1,
      severity: 'failure', message: 'Measured failure', input_revision: release.input_revision)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { edition: 'New reviewed edition' })
    expect { Ai::AcceptFact.call(release_id: release.id, run_id: run.id, candidate_index: 0, expected_revision: release.reload.input_revision) }.to raise_error(Ai::Failure)
    expect(failure.reload.severity).to eq('failure')
    expect(failure.finding_acknowledgements).to be_empty
  end
end
