module Drafts
  class DeleteRequest
    def self.call(release_id:, expected_revision:, remote_id:, snapshot_id:, confirmed:)
      raise Failure.new(:confirmation_required) unless confirmed == true
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless expected_revision == release.input_revision
        snapshot = confirmed_snapshot(release, remote_id, snapshot_id)
        active = release.draft_writes.find_by(state: %w[pending sending unknown])
        return active.workflow_operation if active
        persist(release, snapshot)
      end
    end

    class << self
      private

      def confirmed_snapshot(release, remote_id, snapshot_id)
        raise Failure.new(:not_published) unless release.publication_state == 'published'
        link = release.draft_link
        raise Failure.new(:invalid_link) unless link && link.remote_id == remote_id

        snapshot = release.remote_snapshots.find_by(id: snapshot_id, kind: 'draft', remote_id: remote_id,
          provider_connection_id: link.provider_connection_id, remote_deleted: false)
        snapshot || raise(Failure.new(:observation_changed))
      end

      def persist(release, snapshot)
        link = release.draft_link
        operation = Workflows::Start.call(release_id: release.id, kind: 'draft_delete', request_key: SecureRandom.uuid,
          expected_revision: release.input_revision, parameters: { remote_id: link.remote_id })
        release.draft_writes.create!(workflow_operation: operation, provider_connection: link.provider_connection, action: 'delete', remote_id: link.remote_id,
          request: { 'content' => Content.local(release), 'connection_version' => link.provider_connection.credentials_version,
            'snapshot_id' => snapshot.id, 'remote_content' => snapshot.remote_content })
        operation
      end
    end
  end
end
