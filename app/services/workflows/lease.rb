module Workflows
  class Lease
    DURATION = 5.minutes

    def self.recover(limit:)
      ids = WorkflowOperation.where(state: "running", lease_expires_at: ..Time.current).order(:id).limit(limit).pluck(:id)
      ids.each { |id| expire(operation_id: id) }
      ids
    end

    def self.expire(operation_id:)
      operation = WorkflowOperation.find(operation_id)
      operation.release.with_lock do
        operation.reload
        return operation unless operation.state == "running" && operation.lease_expires_at <= Time.current

        operation.effect == "local" ? requeue(operation) : mark_unknown(operation)
        operation
      end
    end

    def self.renew(operation_id:, attempt_token:)
      operation = WorkflowOperation.find(operation_id)
      operation.with_lock do
        return false unless operation.state == "running" && operation.attempt_token == attempt_token && operation.lease_expires_at.future?

        operation.update!(lease_expires_at: DURATION.from_now)
        true
      end
    end

    def self.requeue(operation)
      operation.update!(state: "pending", phase: "retry_pending", attempt_token: nil, lease_expires_at: nil, error_code: "lease_expired")
      operation.dispatch_intent.update!(state: "pending", dispatch_token: nil, claimed_until: nil, job_id: nil, dispatched_at: nil)
      Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.recovered", data: { operation_id: operation.id })
      ActiveRecord.after_all_transactions_commit { Dispatch.call(operation_id: operation.id) }
    end
    private_class_method :requeue

    def self.mark_unknown(operation)
      operation.update!(state: "outcome_unknown", lease_expires_at: nil, error_code: "effect_interrupted")
      Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.outcome_unknown", data: { operation_id: operation.id })
    end
    private_class_method :mark_unknown
  end
end
