module Workflows
  class Fail
    def self.call(operation_id:, attempt_token:)
      operation = WorkflowOperation.find(operation_id)
      operation.with_lock do
        return unless operation.state == 'running' && operation.attempt_token == attempt_token

        local = operation.effect == 'local'
        state = local ? 'failed' : 'outcome_unknown'
        code = local ? 'execution_failed' : 'effect_interrupted'
        operation.update!(state: state, phase: local ? 'failed' : operation.phase, error_code: code,
          finished_at: local ? Time.current : nil, lease_expires_at: nil)
        Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.#{state}", data: { operation_id: operation.id, error_code: code })
      end
    end
  end
end
