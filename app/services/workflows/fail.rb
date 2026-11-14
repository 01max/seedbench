module Workflows
  class Fail
    class << self
      def call(operation_id:, attempt_token:)
        operation = WorkflowOperation.find(operation_id)
        operation.release.with_lock do
          operation.reload
          return unless operation.state == 'running' && operation.attempt_token == attempt_token

          interrupt(operation)
        end
      end

      private

      def interrupt(operation)
        local = operation.effect == 'local'
        state = local ? 'failed' : 'outcome_unknown'
        code = local ? 'execution_failed' : 'effect_interrupted'
        operation.update!(state: state, phase: local ? 'failed' : operation.phase, error_code: code,
          finished_at: local ? Time.current : nil, lease_expires_at: nil)
        Definitions::ENTRIES[operation.kind]&.interrupted&.call(operation: operation)
        Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.#{operation.state}",
          data: { operation_id: operation.id, error_code: code })
      end
    end
  end
end
