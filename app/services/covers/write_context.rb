module Covers
  class WriteContext
    Snapshot = Data.define(:operation, :cover, :connection)

    class << self
      def call(operation_id:, attempt_token:)
        operation = WorkflowOperation.find(operation_id)
        operation.release.with_lock do
          operation.reload
          validate!(operation, attempt_token)
          cover = operation.release.cover_revisions.order(number: :desc).first
          raise Failure.new(:selection_changed) unless Policy.current?(release: operation.release, cover: cover)

          Snapshot.new(operation: operation, cover: cover, connection: connection(operation.release))
        end
      end

      private

      def validate!(operation, attempt)
        valid = %w[draft_write publish].include?(operation.kind) && operation.effect == 'remote' && operation.state == 'running'
        raise Failure.new(:explicit_write_required) unless valid && operation.attempt_token == attempt && operation.lease_expires_at.future?
        raise Failure.new(:selection_changed) unless operation.input_revision == operation.release.input_revision
      end

      def connection(release)
        assigned = release.provider_assignments.find_by(role: 'image_host')&.provider_connection
        raise Failure.new(:connection_required) unless assigned&.provider == 'postimages' && !assigned.configuration_incomplete?

        assigned
      end
    end
  end
end
