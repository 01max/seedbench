module Duplicates
  class Record
    class << self
      def call(operation:, result:, parameters: operation.parameters)
        verify_connection!(parameters)
        query = parameters.merge(result.except('candidates')).merge('search_operation_id' => operation.id, 'search_id' => SecureRandom.uuid)
        check = operation.release.duplicate_checks.create!(input_revision: operation.input_revision,
          query: query, candidates: result.fetch('candidates'), searched_at: Time.current)
        record_event(operation, check)
        { check_id: check.id, status: result.fetch('status') }
      end

      private

      def verify_connection!(parameters)
        connection = ProviderConnection.find(parameters.fetch('connection_id'))
        raise Failure.new(:connection_changed) unless connection.credentials_version == parameters.fetch('connection_version')
      end

      def record_event(operation, check)
        Releases::RecordEvent.call(release_id: operation.release_id, name: 'duplicates.searched',
          data: { check_id: check.id, status: check.query.fetch('status'), candidates: check.candidates.size })
      end
    end
  end
end
