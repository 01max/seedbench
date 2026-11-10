module Drafts
  class Request
    def self.call(release_id:, expected_revision:)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless expected_revision == release.input_revision
        connection = assigned_connection(release)
        validate!(release)
        active = release.draft_writes.find_by(state: %w[pending sending unknown])
        return active.workflow_operation if active
        persist(release, connection)
      end
    end

    class << self
      private

      def assigned_connection(release)
        connection = release.provider_assignments.find_by!(role: 'publishing').provider_connection
        raise Failure.new(:connection_required) unless connection && !connection.configuration_incomplete?
        raise Failure.new(:different_connection) if release.draft_link && release.draft_link.provider_connection_id != connection.id
        connection
      end

      def validate!(release)
        raise Failure.new(:conflict_required) if release.draft_state == 'conflicted'
        raise Failure.new(:remote_missing) if release.draft_state == 'missing'
        validate_payload!(release)
        raise Failure.new(:published_locked) unless %w[unpublished failed].include?(release.publication_state)
      end

      def validate_payload!(release)
        payload = release.payload_revisions.exists?
        raise Failure.new(:payload_required) unless payload || release.draft_link
        raise Failure.new(:preparation_required) if payload && !Preparation::Current.call(release: release)
      end

      def persist(release, connection)
        link = release.draft_link
        action = link ? 'update' : 'create'
        operation = Workflows::Start.call(release_id: release.id, kind: 'draft_write', request_key: SecureRandom.uuid,
          expected_revision: release.input_revision, parameters: { action: action, connection_id: connection.id })
        release.draft_writes.create!(workflow_operation: operation, provider_connection: connection, action: action, remote_id: link&.remote_id,
          request: snapshot(release, connection))
        operation
      end

      def snapshot(release, connection)
        { 'content' => Content.local(release), 'connection_version' => connection.credentials_version,
          'payload_id' => release.payload_revisions.order(number: :desc).pick(:id),
          'cover_id' => release.cover_revisions.order(number: :desc).pick(:id) }
      end
    end
  end
end
