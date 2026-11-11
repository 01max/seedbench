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
        raise Failure.new(:reconcile_unconfirmed) unless accepting?(receipt)

        reference = { submission_id: receipt.id, info_hash: receipt.info_hash, submission_status: receipt.status }
        persist(reference, receipt.id)
        Seeding::Request.call(operation: @operation, receipt: receipt)
      end
    end

    private

    def accepting?(receipt)
      @operation.phase == Interrupted::SENDING && %w[running outcome_unknown].include?(@operation.state) &&
        %w[submitting outcome_unknown].include?(@release.publication_state) &&
        receipt.info_hash == @operation.external_reference['prepared_info_hash']
    end

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
