module Settings
  class TestConnection
    def self.call(connection_id:)
      connection = ProviderConnection.find(connection_id)
      version = connection.credentials_version
      result = check(connection)
      connection.with_lock do
        raise RotateCredentials::Conflict, "La connexion a changé pendant le test; relancez le test." unless connection.credentials_version == version

        connection.update!(check_status: result.status, check_code: result.code, check_message: result.message, checked_at: Time.current)
      end
      connection
    end

    def self.check(connection)
      raise Providers::Failure.new("unconfigured", "Configuration incomplète pour cette connexion.") if connection.configuration_incomplete?

      Providers::Catalog.adapter(connection).check(connection: connection)
    rescue Providers::Failure => error
      Providers::CheckResult.new(status: "failed", code: error.code, message: error.message)
    end
    private_class_method :check
  end
end
