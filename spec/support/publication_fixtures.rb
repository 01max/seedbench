module PublicationFixtures
  TRACKER = 'https://tracker.c411.org/synthetic-announce/announce'.freeze
  DELUGE = 'http://deluge.test:8112/json'.freeze
  LOCATION = '/client library/books'.freeze

  def ready_to_publish
    release = prepared_draft_payload
    assign_deluge(release)
    host_reviewed_cover(release)
    stub_duplicate_search(body: '<rss><channel/></rss>')
    search_duplicates(release)
    Releases::MarkCheck::KEYS.each do |key|
      Releases::MarkCheck.call(release_id: release.id, expected_revision: release.reload.input_revision, key: key, checked: true)
    end
    release.reload
  end

  def assign_deluge(release)
    connection = create_connection('torrent_client', identity: 'seed-daemon')
    Settings::AssignConnection.call(release_id: release.id, role: 'torrent_client', connection_id: connection.id, expected_revision: release.reload.input_revision)
  end

  def host_reviewed_cover(release)
    stub_cover_hosting
    operation = cover_write_operation(release)
    Covers::Host.call(operation_id: operation.id, attempt_token: operation.attempt_token)
    operation.update!(state: 'succeeded', lease_expires_at: nil, finished_at: Time.current)
    accept_draft_cover(release.reload)
  end

  def request_publication(release)
    Publications::Request.call(release_id: release.id, expected_revision: release.reload.input_revision)
  end

  def stub_publication(preparation)
    stub_draft_categories
    stub_request(:get, submission_url(preparation)).to_return(status: 404)
    receipt = { success: true, data: { id: 42, infoHash: preparation.torrent_info_hash, status: 'approved' } }
    stub_request(:post, 'https://c411.org/api/torrents').to_return(body: receipt.to_json)
  end

  def submission_url(preparation)
    "https://c411.org/api/torrents/#{preparation.torrent_info_hash}"
  end

  def personalized_torrent(preparation)
    bytes = Preparation::Paths.new.path(preparation.torrent_locator, kind: :state).binread
    local = Torrents::Bencode.decode(bytes)
    Torrents::Bencode.encode(local.merge('announce' => TRACKER))
  end

  def stub_personalized_download(preparation, bytes: personalized_torrent(preparation))
    stub_request(:get, 'https://c411.org/api').with(query: {
      t: 'get', id: preparation.torrent_info_hash, apikey: 'synthetic-private-credential'
    }).to_return(body: bytes, headers: { 'Content-Type' => 'application/x-bittorrent' })
  end

  class DelugeSession
    attr_reader :requests

    def initialize(preparation, progress:, tracker_status:, existing:, cached_tracker_status:)
      @preparation, @progress, @tracker_status, @existing = preparation, progress, tracker_status, existing
      @cached_tracker_status = cached_tracker_status
      @requests, @events = [], []
      @state, @move_completed = 'Paused', true
    end

    def response(request)
      body = JSON.parse(request.body)
      method, params = body.values_at('method', 'params')
      @requests << [ method, params ]
      result = send(:rpc_result, method, params)
      { body: { id: body.fetch('id'), result: result, error: nil }.to_json }
    end

    private

    def rpc_result(method, params)
      case method
      when 'auth.login', 'web.connected' then true
      when 'web.get_hosts' then [ [ 'seed-daemon' ] ]
      when 'core.get_session_state' then @existing ? [ @preparation.torrent_info_hash ] : []
      when 'core.get_torrent_status' then status
      when 'web.get_events' then @events.shift(@events.size)
      else mutate(method, params)
      end
    end

    def mutate(method, params)
      case method
      when 'core.add_torrent_file' then @preparation.torrent_info_hash
      when 'core.set_torrent_options' then @move_completed = params.last.fetch('move_completed')
      when 'core.force_recheck' then recheck
      when 'core.resume_torrent' then resume
      when 'core.pause_torrent' then @state = 'Paused'
      end
    end

    def recheck
      @rechecked = true
      @events << [ 'TorrentStateChangedEvent', [ @preparation.torrent_info_hash, 'Paused' ] ]
    end

    def resume
      @state = 'Seeding'
      record_tracker unless @cached_tracker_status
    end

    def status
      { name: @preparation.payload_name, download_location: LOCATION, state: @state, move_completed: @move_completed,
        is_finished: @rechecked && @progress == 100, progress: @rechecked ? @progress : 100,
        tracker_status: tracker_status, trackers: [ { url: TRACKER } ] }
    end

    def tracker_status
      return @cached_tracker_status.to_s unless @state == 'Seeding'
      return @tracker_status unless @cached_tracker_status

      cached = @cached_tracker_status
      @cached_tracker_status = nil
      record_tracker
      cached
    end

    def record_tracker
      @events << [ 'TorrentTrackerStatusEvent', [ @preparation.torrent_info_hash, @tracker_status ] ]
    end
  end

  def stub_seed_daemon(preparation, progress: 100, tracker_status: 'Announce OK', existing: false, cached_tracker_status: nil)
    session = DelugeSession.new(preparation, progress: progress, tracker_status: tracker_status, existing: existing, cached_tracker_status: cached_tracker_status)
    stub_request(:post, DELUGE).to_return { |request| session.response(request) }
    session.requests
  end
end

RSpec.configure { |config| config.include PublicationFixtures }
