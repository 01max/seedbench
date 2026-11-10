module Ai
  class Cancel
    def self.call(operation:)
      run = operation.release.ai_runs.find_by(workflow_operation_id: operation.id)
      run.update!(status: 'stale', error_code: 'input_changed') if run && %w[pending running].include?(run.status)
    end
  end
end
