module Preparation
  class Request
    class << self
      def call(release_id:, expected_revision:)
        release = Release.find(release_id)
        release.with_lock do
          raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

          validate!(release)
          resume_or_start(release)
        end
      end

      private

      def validate!(release)
        raise Failure.new(:published_locked) unless %w[unpublished failed].include?(release.publication_state) && release.seeding_state == 'not_started'
        raise Failure.new(:inspection_required) unless Content::Inputs.new(release).inspected?
        raise Failure.new(:inspection_required) if Releases::Snapshot.call(release: release).findings.any? { |finding| finding.severity == 'failure' }
      end

      def resume_or_start(release)
        previous = release.workflow_operations.where(kind: 'preparation').order(:id).last
        return previous if previous && %w[pending running].include?(previous.state)
        return retry_operation(previous) if previous && recoverable?(previous)

        start(release)
      end

      def start(release)
        payload = release.payload_revisions.order(number: :desc).first!
        names = Providers::C411::EbookNaming.from_release(name: release.proposed_name, format: payload.format)
        release = Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { proposed_name: names.release })
        operation = Workflows::Start.call(release_id: release.id, kind: 'preparation', request_key: SecureRandom.uuid,
          expected_revision: release.input_revision, parameters: { payload_revision_id: payload.id, release_name: names.release })
        release.update!(preparation_state: 'running')
        operation
      end

      def recoverable?(operation)
        operation.state == 'outcome_unknown' || PayloadMove.exists?(workflow_operation_id: operation.id, state: %w[reserved moved])
      end

      def retry_operation(operation)
        operation.update!(state: 'pending', phase: 'retry_pending', attempt_token: nil, lease_expires_at: nil, finished_at: nil)
        operation.dispatch_intent.update!(state: 'pending', dispatch_token: nil, claimed_until: nil, job_id: nil, dispatched_at: nil)
        operation.release.update!(preparation_state: 'running')
        ActiveRecord.after_all_transactions_commit { Workflows::Dispatch.call(operation_id: operation.id) }
        operation
      end
    end
  end
end
