module Publications
  class Request
    class << self
      def call(release_id:, expected_revision:)
        release = Release.find(release_id)
        release.with_lock do
          raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless expected_revision == release.input_revision

          active = release.workflow_operations.find_by(kind: 'publish', state: %w[pending running], input_revision: expected_revision)
          return active if active

          reasons = Gate.call(release: release)
          raise Failure.new(reasons) if reasons.any?

          persist(release)
        end
      end

      private

      def connection(release)
        connection = release.provider_assignments.find_by(role: 'publishing')&.provider_connection
        raise Failure.new(:connection) unless connection && !connection.configuration_incomplete?
        raise Failure.new(:draft_connection) if release.draft_link && release.draft_link.provider_connection_id != connection.id

        connection
      end

      def persist(release)
        assigned = connection(release)
        Workflows::Start.call(release_id: release.id, kind: 'publish', request_key: SecureRandom.uuid,
          expected_revision: release.input_revision, parameters: { connection_id: assigned.id,
            connection_version: assigned.credentials_version, preparation_id: release.preparation_revisions.order(number: :desc).pick(:id),
            manual_search_check_id: Review.manual_search_check_id(release) })
      end
    end
  end
end
