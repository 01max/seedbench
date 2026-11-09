require 'rails_helper'

RSpec.describe Content::Accept do
  let(:release) { reviewed_content_release }
  let(:proposal) { Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'bbcode') }

  it 'offers a replacement without changing text and accepts it exactly once' do
    saved = release.content_revisions.where(kind: 'bbcode').sole.body
    proposal
    expect(release.content_revisions.where(kind: 'bbcode').sole.body).to eq(saved)
    2.times { described_class.call(release_id: release.id, proposal_id: proposal.id, expected_revision: proposal.input_revision) }
    expect(release.content_revisions.where(kind: 'bbcode').count).to eq(2)
    expect(release.content_revisions.where(kind: 'bbcode').last.origin).to eq('generated')
    expect(Content::Status.call(release: release.reload).kinds['bbcode'][:state]).to eq('ready')
  end

  it 'rejects replacement after newer manual text is saved' do
    proposal
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'New human text' })
    expect { described_class.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.reload.input_revision) }.to raise_error(described_class::StaleProposal)
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq('New human text')
  end

  it 'rejects a proposal whose edition facts changed' do
    proposal
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { publisher: 'New publisher' })
    expect { described_class.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.reload.input_revision) }.to raise_error(described_class::StaleProposal)
  end

  it 'accepts an NFO proposal after an unrelated manual BBCode edit' do
    candidate = Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'nfo')
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'Prose manuelle indépendante' })
    described_class.call(release_id: release.id, proposal_id: candidate.id, expected_revision: release.reload.input_revision)
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq('Prose manuelle indépendante')
    expect(release.content_revisions.where(kind: 'nfo').last.body).to eq(candidate.bodies['nfo'])
  end
end
