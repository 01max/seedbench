module Drafts
  class Import
    def self.call(connection:)
      client = Providers::C411::Drafts.new(connection)
      listing = client.list
      errors = listing.ids.filter_map { |id| import_id(connection, client, id) }
      raise errors.first if errors.any?
      listing
    end

    class << self
      private

      def import_id(connection, client, id)
        return if DraftLink.exists?(provider_connection_id: connection.id, remote_id: id)
        data = client.read(id)
        connection.with_lock { import(connection, id, data) }
        nil
      rescue Providers::Failure, Failure => error
        error
      end

      def import(connection, id, data)
        return if DraftLink.exists?(provider_connection_id: connection.id, remote_id: id)
        content = Content.remote(data)
        release = Releases::Create.call(title: content.fetch('title').presence, publishing_connection: connection)
        Content.adopt(release, content)
        DraftLink.create!(release: release, provider_connection: connection, remote_id: id)
        record_snapshot(release, connection, id, data, content)
        release.update!(draft_state: 'synced')
        Releases::RecordEvent.call(release_id: release.id, name: 'draft.imported', data: { remote_id: id })
      end

      def record_snapshot(release, connection, id, data, content)
        release.remote_snapshots.create!(provider_connection: connection, kind: 'draft', remote_id: id, local_revision: release.reload.input_revision,
          remote_revision: data['updatedAt'].to_s.first(100), base_content: content, remote_content: content, observed_at: Time.current)
      end
    end
  end
end
