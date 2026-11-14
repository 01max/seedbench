module Duplicates
  # Runs a queued C411 duplicate search with the recorded queries and verified connection version.
  class Search
    def self.call(operation:)
      connection = ProviderConnection.find(operation.parameters.fetch('connection_id'))
      raise Failure.new(:connection_changed) unless connection.credentials_version == operation.parameters.fetch('connection_version')

      Providers::C411::Search.call(connection: connection, queries: operation.parameters.fetch('queries'))
    end
  end
end
