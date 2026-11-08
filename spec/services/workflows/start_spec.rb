require "rails_helper"

RSpec.describe Workflows::Start do
  let(:release) { build_release_graph }

  before { install_workflow_definition }

  it "persists one operation and dispatch intent with its input identity" do
    operation = start_synthetic_operation(release)

    expect(operation.dispatch_intent.state).to eq("pending")
    expect(operation.input_revision).to eq(0)
    expect(operation.parameters).to eq("payload_revision_id" => release.payload_revisions.sole.id)
    expect(release.release_events.order(:sequence).last.name).to eq("operation.requested")
  end

  it "defers enqueueing until the outer application transaction commits" do
    allow(ActiveRecord).to receive(:after_all_transactions_commit)
    allow(WorkflowOperationJob).to receive(:perform_later)
    start_synthetic_operation(release)

    expect(ActiveRecord).to have_received(:after_all_transactions_commit)
    expect(WorkflowOperationJob).not_to have_received(:perform_later)
  end

  it "returns the same operation on an identical request" do
    operation = start_synthetic_operation(release)

    expect(start_synthetic_operation(release).id).to eq(operation.id)
    expect(release.workflow_operations.count).to eq(1)
    expect(DispatchIntent.count).to eq(1)
  end

  it "rejects request-key reuse for different inputs" do
    start_synthetic_operation(release)

    expect do
      described_class.call(release_id: release.id, kind: "synthetic", request_key: "synthetic-request", expected_revision: 0, parameters: {})
    end.to raise_error(described_class::IdempotencyConflict)
  end

  it "rolls back the intent and operation if event creation fails" do
    id = release.id
    allow(Releases::RecordEvent).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

    expect { start_synthetic_operation(Release.find(id)) }.to raise_error(ActiveRecord::StatementInvalid)
    expect(WorkflowOperation.count).to eq(0)
    expect(DispatchIntent.count).to eq(0)
  end

  it "rejects stale inputs and unimplemented operation kinds", :aggregate_failures do
    expect { described_class.call(release_id: release.id, kind: "synthetic", request_key: "stale", expected_revision: 99) }
      .to raise_error(Releases::RevisionConflict)
    expect { described_class.call(release_id: release.id, kind: "unimplemented", request_key: "unknown", expected_revision: 0) }
      .to raise_error(Workflows::Definitions::UnsupportedKind)
  end
end
