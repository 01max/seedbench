require_relative "../../config/environment"
require_relative "workflow_fixture"

# The isolated runtime stack installs this synthetic definition before starting jobs.
Workflows::Definitions.send(:remove_const, :ENTRIES)
Workflows::Definitions.const_set(:ENTRIES, {
  "synthetic" => Workflows::Definitions::Definition.new(
    compute: SyntheticWorkflow::Compute, apply: SyntheticWorkflow::Apply, effect: "local")
}.freeze)
