require 'rails_helper'

RSpec.describe Content::Confirm do
  let(:release) { reviewed_content_release }

  it 'records explicit review without replacing manually supplied prose' do
    proposal = Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'bbcode')
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { presentation: 'Nouveau texte de travail' })
    before = release.content_revisions.where(kind: 'bbcode').last.body
    described_class.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: 'bbcode')
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq(before)
    expect(Content::Status.call(release: release.reload).kinds['bbcode'][:state]).to eq('ready')
  end

  it 'cannot confirm malformed content or skip current revision checks' do
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision, kind: 'bbcode') }.to raise_error(described_class::InvalidContent)
    expect { described_class.call(release_id: release.id, expected_revision: 99, kind: 'bbcode') }.to raise_error(Releases::RevisionConflict)
  end
end
