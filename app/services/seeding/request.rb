module Seeding
  class Request
    class << self
      def parameters(release)
        connection = release.provider_assignments.find_by(role: 'torrent_client')&.provider_connection
        raise Publications::Failure.new(:deluge_connection) unless connection && !connection.configuration_incomplete?

        { torrent_client_connection_id: connection.id, torrent_client_connection_version: connection.credentials_version,
          client_root: Mapping.client_root }
      rescue Failure
        raise Publications::Failure.new(:mapping), cause: nil
      end

      def call(operation:, receipt:)
        release = operation.release
        Workflows::Start.call(release_id: release.id, kind: 'initial_seed', request_key: "seed-#{operation.id}",
          expected_revision: release.input_revision, parameters: seed_parameters(operation.parameters, receipt))
      end

      private

      def seed_parameters(parameters, receipt)
        parameters.slice('torrent_client_connection_id', 'torrent_client_connection_version', 'preparation_id', 'client_root').merge(
          'publishing_connection_id' => parameters.fetch('connection_id'), 'publishing_connection_version' => parameters.fetch('connection_version'),
          'info_hash' => receipt.info_hash)
      end
    end
  end
end
