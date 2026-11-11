require 'rails_helper'

RSpec.describe Publications::Submit do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { with_preparation_storage { example.run } } }

  let(:release) { ready_to_publish }
  let(:preparation) { release.preparation_revisions.sole }

  def publish
    operation = request_publication(release)
    Workflows::Execute.call(operation_id: operation.id)
    operation.reload
  end

  def seed
    operation = release.workflow_operations.find_by!(kind: 'initial_seed')
    Workflows::Execute.call(operation_id: operation.id)
    operation.reload
  end

  it 'publishes without a draft and preserves the acceptance before initial seeding' do
    sent = stub_publication(preparation)

    operation = publish

    expect(operation.result).to include('status' => 'accepted', 'draft_observation' => 'unlinked')
    expect(release.reload.publication_state).to eq('published')
    expect(release.remote_snapshots.find_by!(kind: 'submission').remote_id).to eq('42')
    expect(sent).to have_been_requested.once
    expect(WebMock).not_to have_requested(:post, 'https://c411.org/api/user/drafts')
  end

  it 'blocks a newly found duplicate before sending the upload' do
    sent = stub_publication(preparation)
    stub_duplicate_search

    expect(publish.result).to include('status' => 'failed', 'errors' => [ 'review_required' ])
    expect(release.reload.publication_state).to eq('unpublished')
    expect(sent).not_to have_been_requested
  end

  it 'rejects changed canonical bytes even when the operator originally passed all gates' do
    sent = stub_publication(preparation)
    operation = request_publication(release)
    Preparation::Paths.new.path(preparation.payload_name).binwrite('Changed bytes')

    Workflows::Execute.call(operation_id: operation.id)

    expect(operation.reload.result).to include('status' => 'failed', 'errors' => [ 'payload_changed' ])
    expect(sent).not_to have_been_requested
  end

  it 'blocks duplicate delivery after a timeout and reconciles one matching submission' do
    stub_publication(preparation)
    sent = stub_request(:post, 'https://c411.org/api/torrents').to_timeout
    operation = publish
    expect(operation.state).to eq('outcome_unknown')
    expect { request_publication(release) }.to raise_error(Publications::Failure, /soumission doit être vérifiée/)
    stub_request(:get, submission_url(preparation)).to_return(body: {
      id: 42, infoHash: preparation.torrent_info_hash, status: 'approved', name: preparation.release_name,
      size: preparation.payload_size_bytes, createdAt: Time.current.iso8601
    }.to_json)

    Publications::Reconcile.call(release_id: release.id)

    expect(release.reload.publication_state).to eq('published')
    expect(release.workflow_operations.where(kind: 'initial_seed').count).to eq(1)
    expect(sent).to have_been_requested.once
  end

  it 'uses the site-issued torrent, sets only per-torrent options and stops after tracker acceptance' do
    stub_publication(preparation)
    stub_personalized_download(preparation)
    requests = stub_seed_daemon(preparation)
    publish
    operation = seed
    added = requests.assoc('core.add_torrent_file').last

    expect(Base64.strict_decode64(added[1])).to eq(personalized_torrent(preparation))
    expect(requests.assoc('core.set_torrent_options').last).to eq([ [ preparation.torrent_info_hash ], { 'move_completed' => false } ])
    expect(requests.assoc('core.set_config')).to be_nil
    expect(release.reload.seeding_state).to eq('succeeded')
    expect { Workflows::Execute.call(operation_id: operation.id) }.not_to change(requests, :size)
  end

  it 'retains a measured 99 percent result and leaves the existing torrent paused' do
    stub_publication(preparation)
    stub_personalized_download(preparation)
    requests = stub_seed_daemon(preparation, progress: 99, existing: true)
    publish

    expect(seed.result).to include('status' => 'failed', 'error_code' => 'recheck_incomplete', 'progress' => 99)
    expect(requests.map(&:first)).not_to include('core.add_torrent_file', 'core.resume_torrent')
    expect(release.reload).to have_attributes(publication_state: 'published', seeding_state: 'failed')
  end

  it 'pauses a torrent whose tracker rejects the first seed without resubmitting' do
    sent = stub_publication(preparation)
    stub_personalized_download(preparation)
    requests = stub_seed_daemon(preparation, tracker_status: 'Error: synthetic rejection')
    publish

    expect(seed.result).to include('status' => 'failed', 'error_code' => 'tracker_rejected')
    expect(requests.map(&:first)).to include('core.pause_torrent')
    expect(release.reload.publication_state).to eq('published')
    expect(sent).to have_been_requested.once
  end

  it 'rejects the local preparation torrent in place of a personalized download' do
    stub_publication(preparation)
    local = Preparation::Paths.new.path(preparation.torrent_locator, kind: :state).binread
    stub_personalized_download(preparation, bytes: local)
    publish

    expect(seed.result).to include('error_code' => 'torrent_tracker')
    expect(WebMock).not_to have_requested(:post, PublicationFixtures::DELUGE)
  end
end
