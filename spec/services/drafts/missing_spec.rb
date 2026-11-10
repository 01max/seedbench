require 'rails_helper'

RSpec.describe Drafts::Missing do
  it 'preserves text, payload and history after a confirmed remote 404 and never recreates implicitly' do
    release = imported_draft
    values = Releases::EditorValues.call(release: release)
    stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 404)
    Drafts::Sync.call(link: release.draft_link)
    expect(release.reload.draft_state).to eq('missing')
    expect(Releases::EditorValues.call(release: release)).to eq(values)
    expect(release.remote_snapshots.last.remote_deleted).to be(true)
    expect { Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision) }.to raise_error(Drafts::Failure)
    expect(WebMock).not_to have_requested(:post, 'https://c411.org/api/user/drafts')
  end

  it 'keeps an authentication or service failure distinct from remote deletion' do
    release = imported_draft
    stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 403)
    expect { Drafts::Sync.call(link: release.draft_link) }.to raise_error(Providers::Failure)
    expect(release.reload.draft_state).to eq('synced')
  end
end
