require "rails_helper"

RSpec.describe WorkflowDispatchRecoveryJob do
  it "dispatches committed pending work in a bounded recovery pass" do
    install_workflow_definition
    allow(ActiveRecord).to receive(:after_all_transactions_commit)
    operation = start_synthetic_operation(build_release_graph)
    allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
    described_class.perform_now

    expect(operation.dispatch_intent.reload.state).to eq("dispatched")
    expect(WorkflowOperationJob).to have_been_enqueued.with(operation.id)
  end
end
