module Drafts
  class Sync
    class << self
      def call(link:)
        base_id = latest_id(link)
        version = link.provider_connection.credentials_version
        data = Providers::C411::Drafts.new(link.provider_connection).read(link.remote_id)
        raise Failure.new(:connection_changed) unless link.provider_connection.reload.credentials_version == version
        Observe.call(link: link, content: Content.remote(data), remote_revision: data['updatedAt'], expected_snapshot_id: base_id)
      end

      private

      def latest_id(link)
        link.release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(id: :desc).pick(:id)
      end
    end
  end
end
