module Seeding
  class Run
    def self.call(operation:)
      new(operation).call
    end

    def initialize(operation)
      @operation, @release = operation, operation.release
      @parameters = operation.parameters
    end

    def call
      start
      preparation = Preparation::Validate.call(release: @release)
      validate_preparation!(preparation)
      artifact = retrieve(preparation)
      client.import(artifact: artifact, preparation: preparation, location: @parameters.fetch('client_root'))
      { 'status' => 'checking' }
    rescue Failure, Providers::Failure, Preparation::Failure => error
      { 'status' => 'failed', 'error_code' => error.code }
    end

    private

    def start
      @release.with_lock do
        raise Failure.new(:publication_required) unless @release.publication_state == 'published' && @release.seeding_state == 'not_started'

        @release.update!(seeding_state: 'checking')
      end
    end

    def validate_preparation!(preparation)
      raise Failure.new(:mapping) unless Mapping.client_root == @parameters.fetch('client_root')
      raise Failure.new(:torrent_mismatch) unless preparation.id == @parameters.fetch('preparation_id')
    end

    def retrieve(preparation)
      connection = configured_connection('publishing')
      bytes = Providers::C411::Publications.new(connection).download(@parameters.fetch('info_hash'))
      Artifact.call(operation: @operation, preparation: preparation, bytes: bytes)
    end

    def client
      Providers::Deluge::Seed.new(connection: configured_connection('torrent_client'), info_hash: @parameters.fetch('info_hash'))
    end

    def configured_connection(role)
      connection = @release.provider_assignments.find_by(role: role)&.provider_connection
      valid = connection && !connection.configuration_incomplete? && connection.id == @parameters.fetch("#{role}_connection_id") &&
        connection.credentials_version == @parameters.fetch("#{role}_connection_version")
      raise Failure.new(:connection_changed) unless valid

      connection
    end
  end
end
