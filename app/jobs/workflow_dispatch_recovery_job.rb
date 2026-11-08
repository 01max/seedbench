class WorkflowDispatchRecoveryJob < ApplicationJob
  queue_as :maintenance

  def perform
    Workflows::RecoverDispatches.call(limit: 100)
  end
end
