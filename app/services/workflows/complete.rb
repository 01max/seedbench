module Workflows
  class Complete
    def self.call(operation_id:, attempt_token:, result:, apply:)
      operation = WorkflowOperation.find(operation_id)
      operation.release.with_lock do
        operation.reload
        return operation unless operation.state == "running" && operation.attempt_token == attempt_token

        summary = apply.call(operation: operation, result: result)
        Releases::EventMetadata.validate!(summary)
        operation.update!(state: "succeeded", phase: "completed", result: summary, finished_at: Time.current, lease_expires_at: nil)
        Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.completed", data: { operation_id: operation.id })
        operation
      end
    end
  end
end
