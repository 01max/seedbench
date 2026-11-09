require 'rails_helper'

RSpec.describe Content::ReviewFacts do
  let(:release) { build_release_graph }

  it 'records deliberate review of unchanged displayed metadata' do
    described_class.call(release_id: release.id, expected_revision: 0)
    expect(release.reload.input_revision).to eq(1)
    expect(release.reviewed_facts.where(field: 'author').sole.value).to eq('Test author')
    expect(release.content_revisions.sole.body).to eq('Human text')
  end

  it 'rejects a stale review before recording facts' do
    expect { described_class.call(release_id: release.id, expected_revision: 5) }.to raise_error(Releases::RevisionConflict)
    expect(release.reviewed_facts.where(field: 'author')).to be_empty
  end
end
