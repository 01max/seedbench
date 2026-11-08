require Rails.root.join("script/quality/workflow_fixture")

module WorkflowFixtures
  def install_workflow_definition(effect: "local")
    definition = Workflows::Definitions::Definition.new(compute: SyntheticWorkflow::Compute, apply: SyntheticWorkflow::Apply, effect: effect)
    stub_const("Workflows::Definitions::ENTRIES", { "synthetic" => definition }.freeze)
  end

  def start_synthetic_operation(release, request_key: "synthetic-request")
    Workflows::Start.call(release_id: release.id, kind: "synthetic", request_key: request_key,
      expected_revision: release.input_revision, parameters: { payload_revision_id: release.payload_revisions.sole.id })
  end
end

RSpec.configure do |config|
  config.include WorkflowFixtures
  config.include ActiveJob::TestHelper
  config.before do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
