require "rails_helper"

RSpec.describe Workflows::Execute do
  let(:release) { build_release_graph }
  let(:operation) { start_synthetic_operation(release) }

  before { install_workflow_definition }

  it "computes outside the command and commits one durable result" do
    described_class.call(operation_id: operation.id)

    expect(operation.reload.state).to eq("succeeded")
    expect(release.evidence_items.find_by!(evidence_key: "workflow-#{operation.id}").data).to include("label" => "Synthetic evidence")
    expect(operation.result).to have_key("evidence_id")
    expect(release.content_revisions.sole.body).to eq("Human text")
  end

  it "records sanitized failure without swallowing the exception" do
    id = operation.id
    allow(SyntheticWorkflow::Compute).to receive(:call).and_raise("synthetic sensitive failure")

    expect { described_class.call(operation_id: id) }.to raise_error(RuntimeError, "synthetic sensitive failure")
    expect(operation.reload.state).to eq("failed")
    expect(operation.error_code).to eq("execution_failed")
    expect(operation.result).to eq({})
  end

  it "does not run an already completed operation again" do
    allow(SyntheticWorkflow::Compute).to receive(:call).and_call_original
    2.times { described_class.call(operation_id: operation.id) }

    expect(SyntheticWorkflow::Compute).to have_received(:call).once
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}").count).to eq(1)
  end
end
