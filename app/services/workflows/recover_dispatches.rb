module Workflows
  class RecoverDispatches
    class << self
      def call(limit: 100)
        raise ArgumentError, I18n.t('messages.workflows.recover_dispatches.recovery_limit_must_be_between_1') unless (1..1000).cover?(limit)

        Lease.recover(limit: limit)
        recover_deliveries(limit)
        ids = DispatchIntent.joins(:workflow_operation).where(workflow_operations: { state: 'pending' })
          .where("dispatch_intents.state = 'pending' OR (dispatch_intents.state = 'dispatching' AND claimed_until <= ?)", Time.current)
          .order(:id).limit(limit).pluck(:workflow_operation_id)
        ids.each { |id| Dispatch.call(operation_id: id) }
        ids
      end

      private

      def recover_deliveries(limit)
        ids = DispatchIntent.joins(:workflow_operation).where(state: 'dispatched', workflow_operations: { state: 'pending' })
          .order(:updated_at, :id).limit(limit).pluck(:workflow_operation_id)
        ids.each { |id| Dispatch.recover(operation_id: id) }
      end
    end
  end
end
