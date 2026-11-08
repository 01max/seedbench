module Settings
  class CompleteConnection
    def self.call(connection_id:, expected_version:, confirm_identity:, credentials:, endpoint: nil, options: {})
      raise ConnectionConfig::Invalid, "Confirmez que la configuration appartient à la même identité." unless confirm_identity == true

      connection = ProviderConnection.find(connection_id)
      connection.with_lock do
        raise RotateCredentials::Conflict, "La connexion a changé; rechargez les réglages." unless connection.credentials_version == expected_version && connection.configuration_incomplete?

        values = configuration(connection, endpoint, credentials, options)
        connection.update!(**values, credentials_version: expected_version + 1,
          check_status: "untested", check_code: nil, check_message: nil, checked_at: nil)
      end
      connection
    end

    def self.configuration(connection, endpoint, credentials, options)
      values = ConnectionConfig.call(role: connection.role, label: connection.label, identity_key: connection.identity_key,
        endpoint: endpoint.presence || connection.endpoint, credentials: credentials, options: options)
      if connection.endpoint
        raise ConnectionConfig::Invalid, "L’adresse déjà enregistrée reste inchangée." unless values.fetch(:endpoint) == connection.endpoint

        values.delete(:endpoint)
      end
      values.slice(:endpoint, :credentials, :options)
    end
    private_class_method :configuration
  end
end
