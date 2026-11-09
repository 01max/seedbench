require 'rails_helper'

RSpec.describe Ebooks::ReviewFact do
  let(:release) { build_release_graph }
  let(:payload) { release.payload_revisions.sole }
  let(:evidence) do
    release.evidence_items.create!(payload_revision: payload, evidence_key: 'catalog', kind: 'edition_record', source: 'Open Library',
      captured_at: Time.current, input_revision: 0, data: { candidates: [ { field: 'title', value: 'Catalog title', source: 'catalog record' } ] })
  end

  it 'requires deliberate review and retains conflicting source candidates' do
    evidence
    expect(release.title).to eq('Synthetic book')
    described_class.call(release_id: release.id, evidence_id: evidence.id, candidate_index: 0, expected_revision: 0)
    expect(release.reload.title).to eq('Catalog title')
    expect(release.reviewed_facts.order(:id).last.fact_evidence_links.sole.evidence_item).to eq(evidence)
    expect(evidence.reload.data.fetch('candidates').first.fetch('value')).to eq('Catalog title')
  end

  it 'rejects stale reviews without replacing human edits' do
    evidence
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { title: 'Human title' })
    expect { described_class.call(release_id: release.id, evidence_id: evidence.id, candidate_index: 0, expected_revision: 0) }.to raise_error(Releases::RevisionConflict)
    expect(release.reload.title).to eq('Human title')
  end

  it 'records provenance when the candidate already matches the displayed value' do
    release.update!(title: 'Catalog title')
    described_class.call(release_id: release.id, evidence_id: evidence.id, candidate_index: 0, expected_revision: 0)
    expect(release.reload.input_revision).to eq(1)
    expect(release.reviewed_facts.where(field: 'title').count).to eq(2)
  end

  it 'rejects negative and forged candidate indexes' do
    expect { described_class.call(release_id: release.id, evidence_id: evidence.id, candidate_index: -1, expected_revision: 0) }.to raise_error(described_class::InvalidCandidate)
  end
end
