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

      private

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
