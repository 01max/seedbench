module Settings
  # Persists a new provider connection using validated settings and encrypted credentials.
  class CreateConnection
    def self.call(**attributes)
      ProviderConnection.create!(ConnectionConfig.call(**attributes).merge(credentials_version: 1))
    rescue ActiveRecord::RecordNotUnique
      raise ConnectionConfig::Invalid, I18n.t('messages.settings.create_connection.cette_identite_existe_deja_pour_ce')
    end
  end
end
