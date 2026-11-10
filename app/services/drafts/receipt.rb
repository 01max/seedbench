module Drafts
  class Receipt
    class << self
      def call(write:, remote_id:)
        release = write.release
        release.with_lock do
          link = release.draft_link || DraftLink.create!(release: release, provider_connection: write.provider_connection, remote_id: remote_id)
          raise Failure.new(:invalid_link) unless link.remote_id == remote_id
          initial_snapshot(release, write, remote_id)
          accept(write, remote_id)
          link
        end
      end

      private

      def initial_snapshot(release, write, remote_id)
        return if release.remote_snapshots.exists?(kind: 'draft', remote_id: remote_id)
        release.remote_snapshots.create!(provider_connection: write.provider_connection, kind: 'draft', remote_id: remote_id,
          local_revision: write.workflow_operation.input_revision, base_content: write.request.fetch('content'),
          remote_content: write.request.fetch('content'), observed_at: Time.current)
      end

      def accept(write, remote_id)
        write.update!(state: 'accepted', remote_id: remote_id, error_code: nil)
        Workflows::RecordOutcome.call(operation_id: write.workflow_operation_id, attempt_token: write.workflow_operation.attempt_token,
          phase: 'draft_accepted', reference: { draft_id: remote_id })
        Releases::RecordEvent.call(release_id: write.release_id, name: 'draft.written', data: { write_id: write.id, remote_id: remote_id })
      end
    end
  end
end
