require "rails_helper"

RSpec.describe Workflows::RecoverDispatches do
  let(:release) { build_release_graph }
  let(:operation) { start_synthetic_operation(release).reload }

  around do |example|
    adapter = WorkflowOperationJob.queue_adapter
    WorkflowOperationJob.queue_adapter = :solid_queue
    example.run
  ensure
    WorkflowOperationJob.queue_adapter = adapter
  end

  before do
    install_workflow_definition
    allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
  end

  def claim_delivery
    process = SolidQueue::Process.register(kind: "Worker", pid: 99_999,
      hostname: "synthetic-test", name: SecureRandom.uuid)
    SolidQueue::ReadyExecution.claim([ "workflow" ], 1, process.id).sole
  end

  def prune_delivery
    claimed = claim_delivery
    process = claimed.process
    process.update!(last_heartbeat_at: 10.minutes.ago)
    process.prune
  end

  it "recovers a queue claim lost before the application attempt and executes once" do
    receipt = operation.dispatch_intent.job_id
    prune_delivery
    described_class.call

    expect(operation.reload.attempts).to eq(0)
    expect(operation.dispatch_intent.reload.job_id).not_to eq(receipt)
    claim_delivery.perform
    WorkflowOperationJob.perform_now(operation.id)
    expect(operation.reload.state).to eq("succeeded")
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}").count).to eq(1)
    expect(release.release_events.where(name: "operation.completed").count).to eq(1)
  end

  it "retains healthy queued deliveries without creating duplicates" do
    receipt = operation.dispatch_intent.job_id
    2.times { described_class.call }

    expect(operation.dispatch_intent.reload.job_id).to eq(receipt)
    expect(SolidQueue::ReadyExecution.count).to eq(1)
    expect(operation.reload.attempts).to eq(0)
  end

  it "retains an active queue claim before the application attempt starts" do
    receipt = operation.dispatch_intent.job_id
    claimed = claim_delivery
    described_class.call

    expect(operation.dispatch_intent.reload.job_id).to eq(receipt)
    expect(SolidQueue::ClaimedExecution.exists?(claimed.id)).to be(true)
    expect(SolidQueue::ReadyExecution.count).to eq(0)
  end

  it "recovers a missing queue receipt" do
    receipt = operation.dispatch_intent.job_id
    SolidQueue::Job.find(receipt).destroy!
    described_class.call

    expect(operation.dispatch_intent.reload.job_id).not_to eq(receipt)
    expect(SolidQueue::ReadyExecution.count).to eq(1)
    expect(operation.reload.attempts).to eq(0)
  end

  it "keeps ordinary execution errors for inspection instead of retrying them" do
    receipt = operation.dispatch_intent.job_id
    claim_delivery.failed_with(RuntimeError.new("Synthetic handler failure"))
    described_class.call

    expect(operation.dispatch_intent.reload.job_id).to eq(receipt)
    expect(SolidQueue::FailedExecution.count).to eq(1)
    expect(SolidQueue::ReadyExecution.count).to eq(0)
  end

  it "never replays a non-local operation whose application attempt became uncertain" do
    install_workflow_definition(effect: "remote")
    receipt = operation.dispatch_intent.job_id
    Workflows::Claim.call(operation_id: operation.id)
    prune_delivery
    operation.update!(lease_expires_at: 1.second.ago)
    described_class.call

    expect(operation.reload.state).to eq("outcome_unknown")
    expect(operation.dispatch_intent.reload.job_id).to eq(receipt)
    expect(SolidQueue::ReadyExecution.count).to eq(0)
  end

  it "visits later receipts even when the first bounded batch is healthy" do
    healthy = operation.dispatch_intent
    lost = start_synthetic_operation(release, request_key: "later-delivery").dispatch_intent.reload
    receipt = lost.job_id
    healthy.update!(updated_at: 2.hours.ago)
    lost.update!(updated_at: 1.hour.ago)
    SolidQueue::Job.find(receipt).destroy!
    2.times { described_class.call(limit: 1) }

    expect(lost.reload.job_id).not_to eq(receipt)
    expect(SolidQueue::ReadyExecution.count).to eq(2)
  end

  it "defers receipt inspection until the enclosing application transaction commits" do
    operation
    allow(ActiveRecord).to receive(:after_all_transactions_commit).and_call_original
    allow(SolidQueue::Job).to receive(:find_by).and_call_original

    ApplicationRecord.transaction(requires_new: true) do
      described_class.call
      expect(SolidQueue::Job).not_to have_received(:find_by)
    end
    expect(SolidQueue::Job).to have_received(:find_by).once
  end

  it "does not inspect another adapter's receipts in Solid Queue" do
    WorkflowOperationJob.queue_adapter = :test
    receipt = operation.dispatch_intent.job_id
    allow(SolidQueue::Job).to receive(:find_by).and_call_original
    described_class.call

    expect(SolidQueue::Job).not_to have_received(:find_by)
    expect(operation.dispatch_intent.reload.job_id).to eq(receipt)
  end

  it "rechecks the application claim after observing a lost queue receipt" do
    receipt = operation.dispatch_intent.job_id
    SolidQueue::Job.find(receipt).destroy!
    allow(SolidQueue::Job).to receive(:find_by).and_wrap_original do |original, **arguments|
      original.call(**arguments).tap { Workflows::Claim.call(operation_id: operation.id) }
    end
    described_class.call

    expect(operation.reload.state).to eq("running")
    expect(operation.dispatch_intent.reload.job_id).to eq(receipt)
    expect(SolidQueue::ReadyExecution.count).to eq(0)
  end
end
