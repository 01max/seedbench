module Drafts
  class DeleteRequest
    def self.call(release_id:, expected_revision:, remote_id:, confirmed:)
      raise Failure.new(:confirmation_required) unless confirmed == true
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless expected_revision == release.input_revision
        validate!(release, remote_id)
        active = release.draft_writes.find_by(state: %w[pending sending unknown])
        return active.workflow_operation if active
        persist(release)
      end
    end

    class << self
      private

      def validate!(release, remote_id)
        raise Failure.new(:not_published) unless release.publication_state == 'published'
        raise Failure.new(:invalid_link) unless release.draft_link&.remote_id == remote_id
      end

      def persist(release)
        link = release.draft_link
        operation = Workflows::Start.call(release_id: release.id, kind: 'draft_delete', request_key: SecureRandom.uuid,
          expected_revision: release.input_revision, parameters: { remote_id: link.remote_id })
        release.draft_writes.create!(workflow_operation: operation, provider_connection: link.provider_connection, action: 'delete', remote_id: link.remote_id,
          request: { 'content' => Content.local(release), 'connection_version' => link.provider_connection.credentials_version,
            'remote_content' => release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last!.remote_content })
        operation
      end
    end
  end
end
