module Settings
  class DefaultsSnapshot
    Snapshot = Data.define(:automatic_ai, :revision, :connection_ids)

    def self.call
      preference = OperatorPreference.find_by(id: 1) || OperatorPreference.new(id: 1)
      connections = ProviderDefault.pluck(:role, :provider_connection_id).to_h
      Snapshot.new(automatic_ai: preference.automatic_ai, revision: preference.revision, connection_ids: connections)
    end
  end
end
