module Settings
  class RotateCredentials
    class Conflict < StandardError; end

    def self.call(connection_id:, expected_version:, confirm_identity:, credentials:)
      raise ConnectionConfig::Invalid, I18n.t('messages.settings.rotate_credentials.confirmez_que_le_secret_appartient_a') unless confirm_identity == true

      connection = ProviderConnection.find(connection_id)
      raise ConnectionConfig::Invalid, I18n.t('messages.settings.rotate_credentials.completez_dabord_la_configuration_de_cette') if connection.configuration_incomplete?

      attributes = ConnectionConfig.call(role: connection.role, label: connection.label, identity_key: connection.identity_key,
        endpoint: connection.endpoint, credentials: credentials, options: connection.options)
      connection.with_lock do
        raise Conflict, I18n.t('messages.settings.rotate_credentials.la_connexion_a_change_rechargez_les') unless connection.credentials_version == expected_version

        connection.update!(credentials: attributes.fetch(:credentials), credentials_version: expected_version + 1,
          check_status: 'untested', check_code: nil, check_message: nil, checked_at: nil)
      end
      connection
    end
  end
end
