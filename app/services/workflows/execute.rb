module Workflows
  class Execute
    def self.call(operation_id:)
      operation = WorkflowOperation.find(operation_id)
      return operation unless operation.state == 'pending'

      definition = Definitions.fetch(operation.kind)
      token = Claim.call(operation_id: operation.id)
      return operation.reload unless token

      result = definition.compute.call(operation: operation.reload)
      Complete.call(operation_id: operation.id, attempt_token: token, result: result, apply: definition.apply)
    rescue StandardError
      Fail.call(operation_id: operation_id, attempt_token: token) if token
      raise
    end
  end
end
