require_relative "fixture_job"
require "timeout"

module RuntimeWorkflows
  def self.release
    id = Rails.application.config.x.storage.fetch(:scratch).join("runtime-release-id").read.to_i
    Release.find(id)
  end

  def self.operation(key)
    release.workflow_operations.find_by!(request_key: key)
  end

  def self.start(key)
    record = release
    Workflows::Start.call(release_id: record.id, kind: "synthetic", request_key: key,
      expected_revision: record.input_revision, parameters: { payload_revision_id: record.payload_revisions.sole.id, pause_compute: true })
  end

  def self.await_marker(operation)
    marker = Rails.application.config.x.storage.fetch(:scratch).join("workflow-started-#{operation.id}")
    Timeout.timeout(10) { sleep 0.05 until marker.exist? }
  end

  def self.continue(operation)
    Rails.application.config.x.storage.fetch(:scratch).join("workflow-continue-#{operation.id}").write("continue")
  end

  def self.verify_gap
    pending = operation("interrupted-dispatch")
    abort "Application intent was not committed" unless pending.state == "pending" && pending.dispatch_intent.state == "pending"
    abort "Queue write happened before the interruption" if SolidQueue::Job.where(class_name: "WorkflowOperationJob").exists?([ "json_extract(arguments, '$.arguments[0]') = ?", pending.id ])
    puts "Process stopped after app commit and before queue write; committed intent retained."
  end

  def self.queue_duplicates
    completed = operation("interrupted-dispatch")
    abort "Recovered operation did not succeed" unless completed.state == "succeeded"
    2.times { WorkflowOperationJob.perform_later(completed.id) }
  end

  def self.release_stale
    stale = operation("stale-compute")
    await_marker(stale)
    record = release
    Releases::Revise.call(release_id: record.id, expected_revision: record.input_revision, changes: { title: "New human title" })
    self.continue(stale)
  end

  def self.checkpoint_crash
    interrupted = operation("interrupted-compute")
    await_marker(interrupted)
    Rails.application.config.x.storage.fetch(:scratch).join("interrupted-attempt").write(interrupted.reload.attempt_token)
  end

  def self.recover_crash
    interrupted = operation("interrupted-compute")
    abort "Killed worker did not leave a running operation" unless interrupted.state == "running"
    interrupted.update!(lease_expires_at: 1.second.ago)
    self.continue(interrupted)
  end

  def self.verify
    record = release
    accepted = operation("interrupted-dispatch")
    interrupted = operation("interrupted-compute")
    stale = operation("stale-compute")
    abort "Duplicate delivery changed attempt count" unless accepted.attempts == 1
    abort "Local crash was not recovered" unless interrupted.state == "succeeded" && interrupted.attempts == 2
    abort "Obsolete result was accepted" unless stale.state == "stale" && !record.evidence_items.exists?(evidence_key: "workflow-#{stale.id}")
    [ accepted, interrupted ].each do |operation|
      abort "Duplicate effect" unless record.evidence_items.where(evidence_key: "workflow-#{operation.id}").count == 1
      abort "Duplicate completion history" unless record.release_events.where(name: "operation.completed").count { |event| event.data["operation_id"] == operation.id } == 1
    end
    old_token = Rails.application.config.x.storage.fetch(:scratch).join("interrupted-attempt").read
    before = interrupted.result
    Workflows::Complete.call(operation_id: interrupted.id, attempt_token: old_token, result: {}, apply: SyntheticWorkflow::Apply)
    abort "Old attempt changed accepted result" unless interrupted.reload.result == before
    abort "Human work changed" unless record.title == "New human title" && record.content_revisions.where(kind: "bbcode").sole.body == "Preserved human content"
    puts "Dispatch-gap recovery, duplicate delivery, stale-result fencing and killed-worker recovery verified."
  end
end

case ARGV.fetch(0)
when "verify_gap" then RuntimeWorkflows.verify_gap
when "queue_duplicates" then RuntimeWorkflows.queue_duplicates
when "start_stale" then RuntimeWorkflows.start("stale-compute")
when "release_stale" then RuntimeWorkflows.release_stale
when "start_crash" then RuntimeWorkflows.start("interrupted-compute")
when "checkpoint_crash" then RuntimeWorkflows.checkpoint_crash
when "recover_crash" then RuntimeWorkflows.recover_crash
when "verify" then RuntimeWorkflows.verify
else abort "Unknown synthetic verification mode"
end
