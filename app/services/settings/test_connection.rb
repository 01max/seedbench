module Settings
  class TestConnection
    class << self
      def call(connection_id:)
        connection = ProviderConnection.find(connection_id)
        version = connection.credentials_version
        result = check(connection)
        connection.with_lock do
          raise RotateCredentials::Conflict, I18n.t('messages.settings.test_connection.la_connexion_a_change_pendant_le') unless connection.credentials_version == version

          connection.update!(check_status: result.status, check_code: result.code, check_message: result.message, checked_at: Time.current)
        end
        connection
      end

      private

      def check(connection)
        raise Providers::Failure.new('unconfigured', I18n.t('messages.settings.test_connection.configuration_incomplete_pour_cette_connexion')) if connection.configuration_incomplete?

        Providers::Catalog.adapter(connection).check(connection: connection)
      rescue Providers::Failure => error
        Providers::CheckResult.new(status: 'failed', code: error.code, message: error.message)
      end
    end
  end
end
