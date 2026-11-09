module Settings
  class CompleteConnection
    class << self
      def call(connection_id:, expected_version:, confirm_identity:, credentials:, endpoint: nil, options: {})
        raise ConnectionConfig::Invalid, I18n.t('messages.settings.complete_connection.confirmez_que_la_configuration_appartient_a') unless confirm_identity == true

        connection = ProviderConnection.find(connection_id)
        connection.with_lock do
          raise RotateCredentials::Conflict, I18n.t('messages.settings.complete_connection.la_connexion_a_change_rechargez_les') unless connection.credentials_version == expected_version && connection.configuration_incomplete?

          values = configuration(connection, endpoint, credentials, options)
          connection.update!(**values, credentials_version: expected_version + 1,
            check_status: 'untested', check_code: nil, check_message: nil, checked_at: nil)
        end
        connection
      end

      private

      def configuration(connection, endpoint, credentials, options)
        values = ConnectionConfig.call(role: connection.role, label: connection.label, identity_key: connection.identity_key,
          endpoint: endpoint.presence || connection.endpoint, credentials: credentials, options: options)
        if connection.endpoint
          raise ConnectionConfig::Invalid, I18n.t('messages.settings.complete_connection.ladresse_deja_enregistree_reste_inchangee') unless values.fetch(:endpoint) == connection.endpoint

          values.delete(:endpoint)
        end
        values.slice(:endpoint, :credentials, :options)
      end
    end
  end
end
