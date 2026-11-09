module Settings
  class ConfigureConnection
    class << self
      def call(connection_id:, expected_version:, options:)
        connection = ProviderConnection.find(connection_id)
        validate_connection!(connection)

        attributes = ConnectionConfig.call(role: connection.role, label: connection.label, identity_key: connection.identity_key,
          endpoint: connection.endpoint, credentials: connection.credentials, options: options)
        connection.with_lock do
          raise RotateCredentials::Conflict, I18n.t('messages.settings.configure_connection.la_connexion_a_change_rechargez_les') unless connection.credentials_version == expected_version

          connection.update!(options: attributes.fetch(:options), credentials_version: expected_version + 1,
            check_status: 'untested', check_code: nil, check_message: nil, checked_at: nil)
        end
        connection
      end

      private

      def validate_connection!(connection)
        raise ConnectionConfig::Invalid, I18n.t('messages.settings.configure_connection.aucune_option_modifiable_pour_ce_role') unless connection.role == 'ai'
        raise ConnectionConfig::Invalid, I18n.t('messages.settings.configure_connection.completez_dabord_la_configuration_de_cette') if connection.configuration_incomplete?
      end
    end
  end
end
