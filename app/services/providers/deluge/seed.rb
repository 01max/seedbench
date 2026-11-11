require 'base64'

module Providers
  class Deluge
    class Seed
      STATUS_FIELDS = %w[name state progress is_finished download_location move_completed tracker_status trackers].freeze

      def initialize(connection:, info_hash:)
        @client, @info_hash = Deluge.new(connection), info_hash
        @client.authenticate!(connection.credentials.fetch('password'))
        @client.connect!(connection.identity_key)
      end

      def import(artifact:, preparation:, location:)
        existing = @client.rpc('core.get_session_state')
        raise Seeding::Failure.new(:deluge_status) unless existing.is_a?(Array)
        return reconcile(status, artifact.trackers, preparation, location) if existing.include?(@info_hash)

        add(artifact.bytes, preparation, location)
        current = status
        return if current['state'] == 'Paused' && matches?(current, artifact.trackers, preparation, location)

        pause
        raise Seeding::Failure.new(:deluge_mismatch)
      end

      def recheck(artifact:, preparation:, location:)
        ensure_paused!
        @client.rpc('core.set_torrent_options', [ [ @info_hash ], { move_completed: false } ])
        start_recheck
        checked = Seeding::Wait.call(seconds: 30) { status if returned_to_paused? }
        verify_recheck!(checked, artifact.trackers, preparation, location)
      rescue Providers::Failure, Seeding::Failure
        ensure_paused!
        raise
      end

      def resume
        @client.rpc('core.resume_torrent', [ @info_hash ])
      end

      private

      def start_recheck
        @client.rpc('web.register_event_listener', [ 'TorrentStateChangedEvent' ])
        @client.rpc('web.get_events')
        @client.rpc('core.force_recheck', [ [ @info_hash ] ])
      end

      def returned_to_paused?
        Array(@client.rpc('web.get_events')).include?([ 'TorrentStateChangedEvent', [ @info_hash, 'Paused' ] ])
      end

      def ensure_paused!
        return if status['state'] == 'Paused'

        pause
        raise Seeding::Failure.new(:pause_unconfirmed) unless Seeding::Wait.call(seconds: 5) { status['state'] == 'Paused' }
      end

      def verify_recheck!(checked, trackers, preparation, location)
        raise Seeding::Failure.new(:recheck_timeout) unless checked
        raise Seeding::Failure.new(:deluge_mismatch) unless matches?(checked, trackers, preparation, location) && paused_without_move?(checked)

        progress = checked['progress']
        raise Seeding::Failure.new(:recheck_incomplete, progress: progress) unless progress == 100 && checked['is_finished'] == true

        progress
      end

      def paused_without_move?(status)
        status['state'] == 'Paused' && status['move_completed'] == false
      end

      def add(bytes, preparation, location)
        options = { download_location: location, add_paused: true, auto_managed: false, seed_mode: false, move_completed: false }
        hash = @client.rpc('core.add_torrent_file', [ "#{preparation.release_name}.torrent", Base64.strict_encode64(bytes), options ])
        raise Seeding::Failure.new(:deluge_import) unless hash == @info_hash
      end

      def reconcile(existing, trackers, preparation, location)
        raise Seeding::Failure.new(:deluge_mismatch) unless matches?(existing, trackers, preparation, location)

        pause unless existing['state'] == 'Paused'
      end

      def matches?(status, trackers, preparation, location)
        status['name'] == preparation.payload_name && status['download_location'] == location &&
          tracker_urls(status) == trackers.sort
      end

      def tracker_urls(status)
        Array(status['trackers']).filter_map { |item| item['url'] if item.is_a?(Hash) }.uniq.sort
      end

      def status
        data = @client.rpc('core.get_torrent_status', [ @info_hash, STATUS_FIELDS ])
        raise Seeding::Failure.new(:deluge_status) unless data.is_a?(Hash)

        data
      end

      def pause
        @client.rpc('core.pause_torrent', [ @info_hash ])
      end
    end
  end
end
