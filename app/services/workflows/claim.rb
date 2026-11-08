module Workflows
  class Claim
    def self.call(operation_id:)
      operation = WorkflowOperation.find(operation_id)
      operation.with_lock do
        return unless operation.state == "pending"

        token = SecureRandom.uuid
        operation.update!(state: "running", phase: "computing", attempt_token: token,
          attempts: operation.attempts + 1, lease_expires_at: 5.minutes.from_now, started_at: Time.current)
        operation.dispatch_intent.update!(state: "dispatched", dispatch_token: nil, claimed_until: nil, dispatched_at: Time.current)
        token
      end
    end
  end
end
