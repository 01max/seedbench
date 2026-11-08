module Settings
  class CreateConnection
    def self.call(**attributes)
      ProviderConnection.create!(ConnectionConfig.call(**attributes).merge(credentials_version: 1))
    rescue ActiveRecord::RecordNotUnique
      raise ConnectionConfig::Invalid, "Cette identité existe déjà pour ce rôle; utilisez sa rotation de secret."
    end
  end
end
