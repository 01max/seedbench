require 'rails_helper'

RSpec.describe Drafts::DeleteRequest do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  it 'alerts on a post-publication leftover and deletes only after explicit confirmation' do
    release = imported_draft
    release.update!(publication_state: 'published')
    expect(Drafts::AfterPublication.call(release_id: release.id)).to be(true)
    snapshot = release.remote_snapshots.last
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision, remote_id: 'draft-1', snapshot_id: snapshot.id, confirmed: false) }.to raise_error(Drafts::Failure)
    operation = described_class.call(release_id: release.id, expected_revision: release.input_revision, remote_id: 'draft-1', snapshot_id: snapshot.id, confirmed: true)
    deleted = stub_request(:delete, 'https://c411.org/api/user/drafts/draft-1').to_return do
      stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 404)
      { body: { success: true }.to_json }
    end
    Workflows::Execute.call(operation_id: operation.id)
    expect(operation.reload.draft_write.state).to eq('accepted')
    expect(deleted).to have_been_requested.once
    expect(release.reload.publication_state).to eq('published')
  end

  it 'rejects cleanup if sync records an edit after the displayed snapshot' do
    release = imported_draft
    release.update!(publication_state: 'published')
    shown = release.remote_snapshots.last
    revision = release.input_revision
    stub_draft_account(draft_data(description: 'Edited after the cleanup form was opened'))
    Drafts::Sync.call(link: release.draft_link)
    expect(release.reload.input_revision).to eq(revision)

    operation = described_class.call(release_id: release.id, expected_revision: revision, remote_id: 'draft-1', snapshot_id: shown.id, confirmed: true)
    Workflows::Execute.call(operation_id: operation.id)

    expect(operation.draft_write.reload).to have_attributes(state: 'failed', error_code: 'observation_changed')
    expect(WebMock).not_to have_requested(:delete, 'https://c411.org/api/user/drafts/draft-1')
  end

  it 'reconciles a deletion timeout by reading absence without sending delete twice' do
    release = imported_draft
    release.update!(publication_state: 'published')
    operation = described_class.call(release_id: release.id, expected_revision: release.input_revision, remote_id: 'draft-1',
      snapshot_id: release.remote_snapshots.last.id, confirmed: true)
    sent = stub_request(:delete, 'https://c411.org/api/user/drafts/draft-1').to_timeout
    Workflows::Execute.call(operation_id: operation.id)
    write = operation.reload.draft_write
    expect(write.state).to eq('unknown')
    stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 404)
    Drafts::Reconcile.call(release_id: release.id, write_id: write.id)
    expect(write.reload.state).to eq('accepted')
    expect(sent).to have_been_requested.once
  end
end
