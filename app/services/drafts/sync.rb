module Drafts
  class Sync
    Observation = Data.define(:snapshot, :data)

    class << self
      def call(link:, expected_body: nil)
        observe(link: link, expected_body: expected_body).snapshot
      end

      def observe(link:, expected_body: nil)
        base_id = link.release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(id: :desc).pick(:id)
        data = fetch(link)
        snapshot = record(link, data, base_id)
        verify_readback(data, expected_body) if expected_body
        AfterPublication.observe(release: link.release, snapshot: snapshot)
        Observation.new(snapshot: snapshot, data: data)
      end

      private

      def verify_readback(data, body)
        valid = data && %w[torrent nfo].all? { |kind| Providers::C411::DraftAttachment.matches?(kind, body, data) }
        raise Failure.new(:readback_mismatch) unless valid
      end

      def record(link, data, base_id)
        return Missing.call(link: link, expected_snapshot_id: base_id) unless data
        Observe.call(link: link, content: Content.remote(data), remote_revision: data['updatedAt'], expected_snapshot_id: base_id)
      end

      def fetch(link)
        version = link.provider_connection.credentials_version
        Providers::C411::Drafts.new(link.provider_connection).read(link.remote_id)
      rescue Providers::Failure => error
        raise unless error.code == 'http_404'
        nil
      ensure
        raise Failure.new(:connection_changed) unless link.provider_connection.reload.credentials_version == version
      end
    end
  end
end
