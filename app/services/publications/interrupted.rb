module Publications
  class Interrupted
    SENDING = 'publication_sending'.freeze

    class << self
      def call(operation:)
        return unless operation.state == 'outcome_unknown'
        return if operation.release.publication_state == 'published'

        if operation.phase == SENDING
          operation.release.update!(publication_state: 'outcome_unknown')
        else
          operation.update!(state: 'failed', phase: 'failed', finished_at: Time.current)
        end
      end

      def resolve_failure(operation:, rejected:)
        release = operation.release
        release.with_lock do
          operation.reload
          return release.publication_state unless operation.phase == SENDING && release.publication_state == 'submitting'

          if rejected
            operation.update!(phase: 'publication_rejected')
            release.update!(publication_state: 'failed')
          else
            operation.update!(state: 'outcome_unknown', error_code: 'submission_unconfirmed', lease_expires_at: nil)
            call(operation: operation)
          end
          release.publication_state
        end
      end
    end
  end
end
