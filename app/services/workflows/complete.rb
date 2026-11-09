module Workflows
  class Complete
    class << self
      def call(operation_id:, attempt_token:, result:, apply:)
        operation = WorkflowOperation.find(operation_id)
        release = operation.release
        release.with_lock do
          operation.reload
          return operation unless operation.state == "running" && operation.attempt_token == attempt_token
          return reject_stale(operation) if operation.input_revision != release.input_revision
          return Lease.expire(operation_id: operation.id) unless operation.lease_expires_at.future?

          apply_result(operation, result, apply)
        end
      end

      private

      def apply_result(operation, result, apply)
        summary = apply.call(operation: operation, result: result)
        Releases::EventMetadata.validate!(summary)
        operation.update!(state: "succeeded", phase: "completed", result: summary, finished_at: Time.current, lease_expires_at: nil)
        Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.completed", data: { operation_id: operation.id })
        operation
      end

      def reject_stale(operation)
        operation.update!(state: "stale", phase: operation.effect == "local" ? "discarded" : operation.phase, error_code: "input_changed", finished_at: Time.current, lease_expires_at: nil)
        Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.stale", data: { operation_id: operation.id })
        Definitions.fetch(operation.kind).stale&.call(operation: operation)
        operation
      end
    end
  end
end
