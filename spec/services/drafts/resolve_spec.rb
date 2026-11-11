require 'rails_helper'

RSpec.describe Drafts::Resolve do
  def conflicted_release
    release = imported_draft
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'Human local edit' })
    stub_draft_account(draft_data(description: 'Remote change'))
    Drafts::Sync.call(link: release.draft_link)
    release.reload
  end

  def resolve(release, choice:, snapshot: release.remote_snapshots.last)
    described_class.call(release_id: release.id, expected_revision: release.input_revision, snapshot_id: snapshot.id, choice: choice)
  end

  it 'retains local text for an explicit later write and records the chosen base' do
    release = conflicted_release
    resolve(release, choice: 'local')
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Human local edit')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Remote change')
    expect(release.release_events.last.data['choice']).to eq('local')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'adopts the reviewed remote text without deleting the human revision' do
    release = conflicted_release
    resolve(release, choice: 'remote')
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Remote change')
    expect(release.content_revisions.pluck(:body)).to include('Human local edit')
    expect(release.reload.draft_state).to eq('synced')
  end

  it 'rejects a resolution if a later remote edit was not displayed' do
    release = conflicted_release
    shown = release.remote_snapshots.last
    stub_draft_account(draft_data(description: 'Later remote edit'))
    expect { resolve(release, choice: 'local', snapshot: shown) }.to raise_error(Drafts::Failure, /autre lecture/)
    expect(release.reload.draft_state).to eq('conflicted')
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Human local edit')
  end
end
