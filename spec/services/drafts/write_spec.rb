require 'rails_helper'

RSpec.describe Drafts::Write do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  let(:remote) { draft_data }

  def writable_shell
    release = imported_draft
    stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return { { body: { success: true, data: remote }.to_json } }
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'Reviewed local description', nfo: 'Reviewed local NFO' })
    release.reload
  end

  def execute(release)
    operation = Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision)
    Workflows::Execute.call(operation_id: operation.id)
    release.draft_writes.order(:id).last
  end

  it 'updates an unlinked shell explicitly, round-trips NFO, and never invents a torrent or category' do
    release = writable_shell
    request = stub_request(:patch, 'https://c411.org/api/user/drafts/draft-1').to_return do |req|
      apply_draft_body(remote, JSON.parse(req.body))
      { body: { success: true }.to_json }
    end
    write = execute(release)
    expect(write.state).to eq('accepted')
    expect(write.body.keys).to contain_exactly('name', 'title', 'description', 'nfoFileName', 'nfoFileData')
    expect(Drafts::Content.remote(remote)['nfo']).to eq('Reviewed local NFO')
    expect(request).to have_been_requested.once
    expect(release.remote_snapshots.last.base_content['description']).to eq('Reviewed local description')
  end

  it 'retains local work after an actual slot-like rejection without assuming the provider error shape' do
    release = writable_shell
    stub_request(:patch, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 422, body: 'private upstream rejection')
    write = execute(release)
    expect(write.state).to eq('failed')
    expect(write.error_code).to eq('http_422')
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Reviewed local description')
    expect(write.attributes.to_json).not_to include('private upstream rejection')
  end

  it 'blocks blind resubmission after timeout and reconciles a matching read without another patch' do
    release = writable_shell
    sent = stub_request(:patch, 'https://c411.org/api/user/drafts/draft-1').to_timeout
    write = execute(release)
    expect(write.state).to eq('unknown')
    expect(Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision).id).to eq(write.workflow_operation_id)
    apply_draft_body(remote, write.body)
    Drafts::Reconcile.call(release_id: release.id, write_id: write.id)
    expect(write.reload.state).to eq('accepted')
    expect(sent).to have_been_requested.once
    expect(release.reload.publication_state).to eq('unpublished')
  end

  it 'stops before writing if pre-write refresh finds a conflict or a changed image is unverified' do
    release = writable_shell
    remote['description'] = 'Other client edit'
    expect(execute(release).error_code).to eq('conflict_required')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'rejects a new unverified image and changed inputs before the HTTP mutation' do
    release = writable_shell
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: '[img]https://images.invalid/unverified.png[/img]' })
    expect(execute(release.reload).error_code).to eq('cover_required')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'retains newer human edits after a successful remote update based on the older approved revision' do
    release = writable_shell
    stub_request(:patch, 'https://c411.org/api/user/drafts/draft-1').to_return do |req|
      apply_draft_body(remote, JSON.parse(req.body))
      Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { bbcode: 'Newer human text', nfo: 'Newer human NFO' })
      { body: { success: true }.to_json }
    end
    write = execute(release)
    expect(write.state).to eq('accepted')
    expect(write.workflow_operation.state).to eq('succeeded')
    expect(release.reload.draft_state).to eq('conflicted')
    expect(Releases::EditorValues.call(release: release)).to include('bbcode' => 'Newer human text', 'nfo' => 'Newer human NFO')
  end
end
