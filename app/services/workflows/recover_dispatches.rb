module Workflows
  class RecoverDispatches
    def self.call(limit: 100)
      raise ArgumentError, "Recovery limit must be between 1 and 1000." unless (1..1000).cover?(limit)

      ids = DispatchIntent.joins(:workflow_operation).where(workflow_operations: { state: "pending" })
        .where("dispatch_intents.state = 'pending' OR (dispatch_intents.state = 'dispatching' AND claimed_until <= ?)", Time.current)
        .order(:id).limit(limit).pluck(:workflow_operation_id)
      ids.each { |id| Dispatch.call(operation_id: id) }
      ids
    end
  end
end
