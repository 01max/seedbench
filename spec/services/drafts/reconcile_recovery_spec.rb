require 'rails_helper'

RSpec.describe Drafts::Reconcile do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  it 'closes an interrupted pre-transmission operation without sending a provider request' do
    release = imported_draft
    operation = Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision)
    token = Workflows::Claim.call(operation_id: operation.id)
    Workflows::Fail.call(operation_id: operation.id, attempt_token: token)
    write = operation.reload.draft_write
    described_class.call(release_id: release.id, write_id: write.id)
    expect(write.reload.state).to eq('failed')
    expect(write.error_code).to eq('interrupted_before_send')
    expect(operation.reload.state).to eq('failed')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'retains the approved body and remote identity against SQL changes or deletion' do
    release = imported_draft
    operation = Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision)
    write = operation.draft_write
    write.update!(body: { description: 'Approved body' }, state: 'unknown')
    connection = ApplicationRecord.connection
    [ "UPDATE draft_writes SET request = '{}' WHERE id = #{write.id}",
      "UPDATE draft_writes SET body = '{}' WHERE id = #{write.id}",
      "UPDATE draft_writes SET remote_id = 'other' WHERE id = #{write.id}",
      "DELETE FROM draft_writes WHERE id = #{write.id}" ].each do |sql|
      expect { connection.execute(sql) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  it 'cancels a stale unstarted write instead of stranding a pending receipt or sending old text' do
    release = imported_draft
    operation = Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'Newer human text' })
    Workflows::Execute.call(operation_id: operation.id)
    expect(operation.reload.state).to eq('stale')
    expect(operation.draft_write.reload.error_code).to eq('input_changed')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end
end
