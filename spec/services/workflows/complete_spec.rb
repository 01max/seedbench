require "rails_helper"

RSpec.describe Workflows::Complete do
  let(:release) { build_release_graph }
  let(:operation) { start_synthetic_operation(release) }
  let(:token) { Workflows::Claim.call(operation_id: operation.id) }

  before { install_workflow_definition }

  def complete_with(attempt)
    described_class.call(operation_id: operation.id, attempt_token: attempt, result: { "label" => "computed" }, apply: SyntheticWorkflow::Apply)
  end

  it "rejects an attempt that does not own the operation" do
    token
    complete_with("superseded")

    expect(operation.reload.state).to eq("running")
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}")).to be_empty
  end

  it "accepts an attempt once even when completion is delivered twice" do
    2.times { complete_with(token) }

    expect(operation.reload.state).to eq("succeeded")
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}").count).to eq(1)
    expect(release.release_events.where(name: "operation.completed").count).to eq(1)
  end

  it "preserves newer human edits when computation finishes late", :aggregate_failures do
    token
    Releases::Revise.call(release_id: release.id, expected_revision: 0, changes: { title: "New human title" })
    complete_with(token)

    expect(operation.reload.state).to eq("stale")
    expect(release.reload.title).to eq("New human title")
    expect(release.content_revisions.sole.body).to eq("Human text")
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}")).to be_empty
  end

  it "does not accept a result after its lease expires" do
    current = token
    operation.update!(lease_expires_at: 1.second.ago)
    complete_with(current)

    expect(operation.reload.state).to eq("pending")
    expect(operation.attempt_token).to be_nil
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}")).to be_empty
  end

  it "rolls back partial local effects when applying a result raises" do
    id = operation.id
    allow(SyntheticWorkflow::Apply).to receive(:call).and_wrap_original do |original, **arguments|
      original.call(**arguments)
      raise "Synthetic interrupted apply"
    end

    expect { Workflows::Execute.call(operation_id: id) }.to raise_error(RuntimeError, "Synthetic interrupted apply")
    expect(operation.reload.state).to eq("failed")
    expect(release.evidence_items.where(evidence_key: "workflow-#{id}")).to be_empty
  end
end
