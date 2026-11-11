module Publications
  class Receipt
    def self.call(operation:, receipt:)
      new(operation).call(receipt)
    end

    def initialize(operation)
      @operation, @release = operation, operation.release
    end

    def call(receipt)
      @release.with_lock do
        @operation.reload
        return if @release.publication_state == 'published'

        reference = { submission_id: receipt.id, info_hash: receipt.info_hash, submission_status: receipt.status }
        persist(reference, receipt.id)
        Seeding::Request.call(operation: @operation, receipt: receipt)
      end
    end

    private

    def persist(reference, id)
      Workflows::RecordOutcome.call(operation_id: @operation.id, attempt_token: @operation.attempt_token,
        phase: 'publication_accepted', reference: reference)
      @release.remote_snapshots.create!(provider_connection_id: @operation.parameters.fetch('connection_id'), kind: 'submission',
        remote_id: id.to_s, local_revision: @operation.input_revision, observed_at: Time.current, remote_content: reference)
      @release.update!(publication_state: 'published')
      Releases::RecordEvent.call(release_id: @release.id, name: 'publication.accepted', data: reference.merge(operation_id: @operation.id))
    end
  end
end
