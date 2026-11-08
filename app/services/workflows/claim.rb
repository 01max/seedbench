module Workflows
  class Claim
    def self.call(operation_id:)
      operation = WorkflowOperation.find(operation_id)
      release = operation.release
      release.with_lock do
        operation.reload
        return unless operation.state == "pending"
        return reject_stale(operation) if operation.input_revision != release.input_revision

        activate(operation)
      end
    end

    def self.activate(operation)
      token = SecureRandom.uuid
      operation.update!(state: "running", phase: "computing", attempt_token: token,
        attempts: operation.attempts + 1, lease_expires_at: Lease::DURATION.from_now, started_at: Time.current, error_code: nil)
      operation.dispatch_intent.update!(state: "dispatched", dispatch_token: nil, claimed_until: nil, dispatched_at: Time.current)
      token
    end
    private_class_method :activate

    def self.reject_stale(operation)
      operation.update!(state: "stale", phase: "discarded", error_code: "input_changed", finished_at: Time.current)
      operation.dispatch_intent.update!(state: "dispatched", dispatch_token: nil, claimed_until: nil, dispatched_at: Time.current)
      Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.stale", data: { operation_id: operation.id })
      nil
    end
    private_class_method :reject_stale
  end
end
