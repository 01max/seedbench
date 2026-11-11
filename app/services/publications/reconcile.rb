module Publications
  class Reconcile
    def self.call(release_id:)
      new(Release.find(release_id)).call
    end

    def initialize(release)
      @release = release
    end

    def call
      @operation = @release.workflow_operations.where(kind: 'publish', state: 'outcome_unknown').order(:id).last
      raise Failure.new(:reconcile_unconfirmed) unless @operation&.phase == Interrupted::SENDING

      reference = @operation.external_reference
      detail = read(reference.fetch('prepared_info_hash'))
      raise Failure.new(:reconcile_unconfirmed) unless matches?(detail, reference)

      result = confirm(detail.receipt)
      result['draft_observation'] = DraftObservation.call(release: @release)
      @operation.update!(result: result)
      result
    end

    private

    def read(info_hash)
      connection = ProviderConnection.find(@operation.parameters.fetch('connection_id'))
      raise Failure.new(:connection) if connection.configuration_incomplete?

      Providers::C411::Publications.new(connection).read(info_hash)
    end

    def matches?(detail, reference)
      return false unless detail

      preparation = @release.preparation_revisions.find(@operation.parameters.fetch('preparation_id'))
      started_at = Time.iso8601(reference.fetch('sending_at'))
      detail.name == preparation.release_name && detail.size == preparation.payload_size_bytes &&
        detail.created_at.between?(started_at - 2.seconds, Time.current + 5.seconds)
    end

    def confirm(receipt)
      @release.with_lock do
        @operation.reload
        raise Failure.new(:reconcile_unconfirmed) unless @operation.state == 'outcome_unknown' && @release.publication_state == 'outcome_unknown'

        Receipt.call(operation: @operation, receipt: receipt)
        result = { 'status' => 'accepted', 'reconciled' => true }
        @operation.update!(state: 'succeeded', phase: 'reconciled', result: result, error_code: nil, finished_at: Time.current)
        result
      end
    end
  end
end
