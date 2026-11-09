require 'rails_helper'

RSpec.describe WorkflowOperationJob do
  it 'executes a persisted operation through the application service' do
    install_workflow_definition
    release = build_release_graph
    operation = start_synthetic_operation(release)
    described_class.perform_now(operation.id)

    expect(operation.reload.state).to eq('succeeded')
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}").count).to eq(1)
  end
end
