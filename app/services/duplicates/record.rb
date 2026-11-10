module Duplicates
  class Record
    class << self
      def call(operation:, result:)
        verify_connection!(operation)
        query = operation.parameters.merge(result.except('candidates')).merge('search_operation_id' => operation.id)
        check = operation.release.duplicate_checks.create!(input_revision: operation.input_revision,
          query: query, candidates: result.fetch('candidates'), searched_at: Time.current)
        record_event(operation, check)
        { check_id: check.id, status: result.fetch('status') }
      end

      private

      def verify_connection!(operation)
        connection = ProviderConnection.find(operation.parameters.fetch('connection_id'))
        raise Failure.new(:connection_changed) unless connection.credentials_version == operation.parameters.fetch('connection_version')
      end

      def record_event(operation, check)
        Releases::RecordEvent.call(release_id: operation.release_id, name: 'duplicates.searched',
          data: { check_id: check.id, status: check.query.fetch('status'), candidates: check.candidates.size })
      end
    end
  end
end
