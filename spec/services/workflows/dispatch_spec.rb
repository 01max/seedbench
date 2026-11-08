require "rails_helper"

RSpec.describe Workflows::Dispatch do
  let(:release) { build_release_graph }
  let(:operation) { start_synthetic_operation(release) }

  before do
    install_workflow_definition
    allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
  end

  it "enqueues the committed identity and records its receipt" do
    described_class.call(operation_id: operation.id)

    expect(operation.dispatch_intent.reload.state).to eq("dispatched")
    expect(WorkflowOperationJob).to have_been_enqueued.with(operation.id).exactly(:once)
  end

  it "retains pending intent when the queue rejects enqueueing" do
    allow(WorkflowOperationJob).to receive(:perform_later).and_raise(ActiveJob::EnqueueError)
    described_class.call(operation_id: operation.id)

    expect(operation.dispatch_intent.reload.state).to eq("pending")
    expect(operation.dispatch_intent.error_code).to eq("enqueue_failed")
  end

  it "does not duplicate a currently claimed dispatch" do
    intent = operation.dispatch_intent
    intent.update!(state: "dispatching", dispatch_token: "other-attempt", claimed_until: 1.minute.from_now)
    clear_enqueued_jobs
    described_class.call(operation_id: operation.id)

    expect(WorkflowOperationJob).not_to have_been_enqueued
  end

  it "recovers the enqueue-before-receipt interruption window" do
    intent = operation.dispatch_intent
    intent.update!(state: "dispatching", dispatch_token: "interrupted", claimed_until: 1.minute.ago)
    clear_enqueued_jobs
    Workflows::RecoverDispatches.call(limit: 1)

    expect(intent.reload.state).to eq("dispatched")
    expect(WorkflowOperationJob).to have_been_enqueued.with(operation.id)
  end
end
