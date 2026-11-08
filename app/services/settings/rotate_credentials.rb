module Settings
  class RotateCredentials
    class Conflict < StandardError; end

    def self.call(connection_id:, expected_version:, confirm_identity:, credentials:)
      raise ConnectionConfig::Invalid, "Confirmez que le secret appartient à la même identité." unless confirm_identity == true

      connection = ProviderConnection.find(connection_id)
      attributes = ConnectionConfig.call(role: connection.role, label: connection.label, identity_key: connection.identity_key,
        endpoint: connection.endpoint, credentials: credentials, options: connection.options)
      connection.with_lock do
        raise Conflict, "La connexion a changé; rechargez les réglages." unless connection.credentials_version == expected_version

        connection.update!(credentials: attributes.fetch(:credentials), credentials_version: expected_version + 1,
          check_status: "untested", check_code: nil, check_message: nil, checked_at: nil)
      end
      connection
    end
  end
end
