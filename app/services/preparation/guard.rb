module Preparation
  class Guard
    class << self
      def call(operation:, attempt:)
        release = operation.release.reload
        unpublished!(release)
        raise Releases::RevisionConflict.new(expected_revision: operation.input_revision, actual_revision: release.input_revision) unless operation.input_revision == release.input_revision
        raise Failure.new(:payload_changed) unless release.payload_revisions.order(number: :desc).pick(:id) == operation.parameters.fetch('payload_revision_id')

        active!(operation, attempt)
      end

      private

      def unpublished!(release)
        raise Failure.new(:published_locked) unless %w[unpublished failed].include?(release.publication_state) && release.seeding_state == 'not_started'
      end

      def active!(operation, attempt)
        operation.reload
        raise Failure.new(:operation_expired) unless operation.state == 'running' && operation.attempt_token == attempt && operation.lease_expires_at.future?
      end
    end
  end
end
