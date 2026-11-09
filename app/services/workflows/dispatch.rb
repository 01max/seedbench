module Workflows
  class Dispatch
    PROCESS_FAILURES = %w[SolidQueue::Processes::ProcessPrunedError SolidQueue::Processes::ProcessExitError SolidQueue::Processes::ProcessMissingError].freeze

    class << self
      def call(operation_id:)
        ActiveRecord.after_all_transactions_commit { enqueue(operation_id) }
      end

      def recover(operation_id:)
        return unless WorkflowOperationJob.queue_adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter)

        ActiveRecord.after_all_transactions_commit { reconcile(operation_id) }
      end

      private

      def reconcile(operation_id)
        operation = WorkflowOperation.find(operation_id)
        intent = operation.dispatch_intent
        return unless operation.state == 'pending' && intent.state == 'dispatched'

        receipt = intent.job_id
        lost = receipt_lost?(receipt)
        reconcile_receipt(operation, intent, receipt, lost)
      end

      def receipt_lost?(receipt)
        job = SolidQueue::Job.find_by(id: receipt, class_name: WorkflowOperationJob.name)
        job.nil? || PROCESS_FAILURES.include?(job.failed_execution&.exception_class)
      end

      def reconcile_receipt(operation, intent, receipt, lost)
        operation.release.with_lock do
          operation.reload
          intent.reload
          return unless operation.state == 'pending' && intent.state == 'dispatched' && intent.job_id == receipt

          lost ? redeliver(operation, intent) : intent.update!(updated_at: Time.current)
        end
      end

      def redeliver(operation, intent)
        receipt = intent.job_id
        intent.update!(state: 'pending', dispatch_token: nil, claimed_until: nil, job_id: nil, dispatched_at: nil, error_code: 'delivery_lost')
        Releases::RecordEvent.call(release_id: operation.release_id, name: 'operation.delivery_recovered',
          data: { operation_id: operation.id, queue_job_id: receipt })
        ActiveRecord.after_all_transactions_commit { call(operation_id: operation.id) }
      end

      def enqueue(operation_id)
        operation = WorkflowOperation.find(operation_id)
        return unless operation.state == 'pending'

        intent = operation.dispatch_intent
        token = claim(intent)
        deliver(operation, intent, token) if token
      end

      def claim(intent)
        intent.with_lock do
          return if intent.state == 'dispatched'
          return if intent.state == 'dispatching' && intent.claimed_until.future?

          token = SecureRandom.uuid
          intent.update!(state: 'dispatching', dispatch_token: token, claimed_until: 30.seconds.from_now, attempts: intent.attempts + 1)
          token
        end
      end

      def deliver(operation, intent, token)
        job = WorkflowOperationJob.perform_later(operation.id)
        if job && job.successfully_enqueued?
          finish(intent, token, state: 'dispatched', dispatched_at: Time.current, job_id: job.provider_job_id || job.job_id, error_code: nil)
        else
          finish(intent, token, state: 'pending', error_code: 'enqueue_failed')
        end
      rescue ActiveJob::EnqueueError, SolidQueue::Job::EnqueueError
        finish(intent, token, state: 'pending', error_code: 'enqueue_failed')
      end

      def finish(intent, token, **attributes)
        intent.with_lock do
          return unless intent.dispatch_token == token

          intent.update!(**attributes, dispatch_token: nil, claimed_until: nil)
        end
      end
    end
  end
end
