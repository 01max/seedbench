class WorkflowOperationJob < ApplicationJob
  queue_as :workflow

  def perform(operation_id)
    Workflows::Execute.call(operation_id: operation_id)
  end
end
