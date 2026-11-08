module Settings
  class ConfigureConnection
    def self.call(connection_id:, expected_version:, options:)
      connection = ProviderConnection.find(connection_id)
      raise ConnectionConfig::Invalid, "Aucune option modifiable pour ce rôle." unless connection.role == "ai"
      raise ConnectionConfig::Invalid, "Complétez d’abord la configuration de cette connexion." if connection.configuration_incomplete?

      attributes = ConnectionConfig.call(role: connection.role, label: connection.label, identity_key: connection.identity_key,
        endpoint: connection.endpoint, credentials: connection.credentials, options: options)
      connection.with_lock do
        raise RotateCredentials::Conflict, "La connexion a changé; rechargez les réglages." unless connection.credentials_version == expected_version

        connection.update!(options: attributes.fetch(:options), credentials_version: expected_version + 1,
          check_status: "untested", check_code: nil, check_message: nil, checked_at: nil)
      end
      connection
    end
  end
end
