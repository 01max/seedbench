require_relative "fixture_job"

release_id = Rails.application.config.x.storage.fetch(:scratch).join("runtime-release-id").read.to_i
release = Release.find(release_id)
Workflows::Dispatch.define_singleton_method(:call) { |**_arguments| Process.exit!(29) }
Workflows::Start.call(release_id: release.id, kind: "synthetic", request_key: "interrupted-dispatch",
  expected_revision: release.input_revision, parameters: { payload_revision_id: release.payload_revisions.sole.id })
abort "The committed-dispatch interruption did not occur"
