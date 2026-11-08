module Workflows
  class Dispatch
    def self.call(operation_id:)
      ActiveRecord.after_all_transactions_commit { enqueue(operation_id) }
    end

    def self.enqueue(operation_id)
      operation = WorkflowOperation.find(operation_id)
      return unless operation.state == "pending"

      intent = operation.dispatch_intent
      token = claim(intent)
      deliver(operation, intent, token) if token
    end
    private_class_method :enqueue

    def self.claim(intent)
      intent.with_lock do
        return if intent.state == "dispatched"
        return if intent.state == "dispatching" && intent.claimed_until.future?

        token = SecureRandom.uuid
        intent.update!(state: "dispatching", dispatch_token: token, claimed_until: 30.seconds.from_now, attempts: intent.attempts + 1)
        token
      end
    end
    private_class_method :claim

    def self.deliver(operation, intent, token)
      job = WorkflowOperationJob.perform_later(operation.id)
      if job && job.successfully_enqueued?
        finish(intent, token, state: "dispatched", dispatched_at: Time.current, job_id: job.provider_job_id || job.job_id, error_code: nil)
      else
        finish(intent, token, state: "pending", error_code: "enqueue_failed")
      end
    rescue ActiveJob::EnqueueError, SolidQueue::Job::EnqueueError
      finish(intent, token, state: "pending", error_code: "enqueue_failed")
    end
    private_class_method :deliver

    def self.finish(intent, token, **attributes)
      intent.with_lock do
        return unless intent.dispatch_token == token

        intent.update!(**attributes, dispatch_token: nil, claimed_until: nil)
      end
    end
    private_class_method :finish
  end
end
