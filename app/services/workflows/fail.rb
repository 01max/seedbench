module Workflows
  class Fail
    def self.call(operation_id:, attempt_token:)
      operation = WorkflowOperation.find(operation_id)
      operation.with_lock do
        return unless operation.state == "running" && operation.attempt_token == attempt_token

        operation.update!(state: "failed", phase: "failed", error_code: "execution_failed", finished_at: Time.current, lease_expires_at: nil)
        Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.failed", data: { operation_id: operation.id, error_code: "execution_failed" })
      end
    end
  end
end
