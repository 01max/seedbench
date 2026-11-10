module Duplicates
  class Request
    class << self
      def call(release_id:, expected_revision:)
        release = Release.find(release_id)
        release.with_lock do
          raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

          Workflows::Start.call(release_id: release.id, kind: 'duplicate_search', expected_revision: expected_revision,
            request_key: SecureRandom.uuid, parameters: parameters(release))
        end
      end

      private

      def parameters(release)
        connection = release.provider_assignments.find_by(role: 'publishing')&.provider_connection
        raise Failure.new(:connection_required) unless connection&.provider == 'c411' && !connection.configuration_incomplete?

        inputs = Inputs.call(release: release)
        raise Failure.new(:title_required) if inputs['title'].blank?

        { connection_id: connection.id, connection_version: connection.credentials_version,
          inputs: inputs, fingerprint: Inputs.fingerprint(inputs), queries: Inputs.queries(inputs) }
      end
    end
  end
end
