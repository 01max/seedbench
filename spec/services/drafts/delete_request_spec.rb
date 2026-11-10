require 'rails_helper'

RSpec.describe Drafts::DeleteRequest do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  it 'alerts on a post-publication leftover and deletes only after explicit confirmation' do
    release = imported_draft
    release.update!(publication_state: 'published')
    expect(Drafts::AfterPublication.call(release_id: release.id)).to be(true)
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision, remote_id: 'draft-1', confirmed: false) }.to raise_error(Drafts::Failure)
    operation = described_class.call(release_id: release.id, expected_revision: release.input_revision, remote_id: 'draft-1', confirmed: true)
    deleted = stub_request(:delete, 'https://c411.org/api/user/drafts/draft-1').to_return do
      stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 404)
      { body: { success: true }.to_json }
    end
    Workflows::Execute.call(operation_id: operation.id)
    expect(operation.reload.draft_write.state).to eq('accepted')
    expect(deleted).to have_been_requested.once
    expect(release.reload.publication_state).to eq('published')
  end

  it 'reconciles a deletion timeout by reading absence without sending delete twice' do
    release = imported_draft
    release.update!(publication_state: 'published')
    operation = described_class.call(release_id: release.id, expected_revision: release.input_revision, remote_id: 'draft-1', confirmed: true)
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
