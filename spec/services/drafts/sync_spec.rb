require 'rails_helper'

RSpec.describe Drafts::Sync do
  let(:release) { imported_draft }

  def sync(data)
    stub_draft_account(data)
    described_class.call(link: release.draft_link)
    release.reload
  end

  def edit(body)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: body })
    release.reload
  end

  it 'adopts remote-only changes and advances the base with append-only local content' do
    original = release.content_revisions.last
    sync(draft_data(description: 'Remote-only edit'))
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Remote-only edit')
    expect(original.reload.body).to eq('Description distante conservée.')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Remote-only edit')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'retains both copies and the original base when both sides change' do
    edit('Local changed')
    sync(draft_data(description: 'Remote changed'))
    expect(release.draft_state).to eq('conflicted')
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Local changed')
    expect(release.remote_snapshots.last.remote_content['description']).to eq('Remote changed')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Description distante conservée.')
  end

  it 'retains unsent local edits and converges when the remote becomes identical' do
    edit('Local changed')
    sync(draft_data)
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Local changed')
    sync(draft_data(description: 'Local changed'))
    expect(release.draft_state).to eq('synced')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Local changed')
  end

  it 'does not turn a failed account refresh into an implicit mutation' do
    connection = release.draft_link.provider_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 503)
    error = Drafts::Refresh.call(connection: connection)
    expect(error).to include('HTTP 503')
    expect(release.reload.draft_state).to eq('synced')
    expect(WebMock).not_to have_requested(:delete, /c411/)
  end
end
