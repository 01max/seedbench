require 'rails_helper'

RSpec.describe Content::Status do
  let(:release) { reviewed_content_release }

  def accept_generated(kind)
    proposal = Content::Propose.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: kind)
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
  end

  it 'marks only affected content stale while retaining human text' do
    accept_generated('bbcode')
    accept_generated('nfo')
    body = release.content_revisions.where(kind: 'bbcode').last.body
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { presentation: 'Nouvelle présentation' })
    state = described_class.call(release: release.reload)
    expect(state.kinds['bbcode'][:state]).to eq('stale')
    expect(state.kinds['nfo'][:state]).to eq('ready')
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq(body)
  end

  it 'detects stale NFO when preparation becomes current' do
    accept_generated('nfo')
    mark_preparation_current(release)
    expect(described_class.call(release: release).kinds['nfo'][:state]).to eq('stale')
  end

  it 'detects a changed selected cover without invalidating NFO' do
    accept_generated('bbcode')
    accept_generated('nfo')
    release.cover_revisions.create!(payload_revision: release.payload_revisions.sole, number: 2, source_kind: 'embedded',
      source_locator: 'covers/new.png', width: 600, height: 900)
    state = described_class.call(release: release.reload)
    expect(state.kinds['bbcode'][:state]).to eq('stale')
    expect(state.kinds['nfo'][:state]).to eq('ready')
  end
end
