module Settings
  class SetDefaults
    class Invalid < StandardError; end
    class Conflict < StandardError; end

    def self.call(automatic_ai:, connection_ids:, expected_revision:)
      raise Invalid, "Réglages par défaut invalides." unless valid_input?(automatic_ai, connection_ids)

      OperatorPreference.transaction do
        preference = OperatorPreference.find_or_create_by!(id: 1)
        raise Conflict, "Les réglages ont changé; rechargez la page." unless preference.revision == expected_revision

        connection_ids.each { |role, id| ProviderDefault.find_or_initialize_by(role: role).update!(provider_connection_id: resolve(role, id)) }
        preference.update!(automatic_ai: automatic_ai, revision: preference.revision + 1)
      end
      DefaultsSnapshot.call
    end

    def self.valid_input?(automatic_ai, connection_ids)
      [ true, false ].include?(automatic_ai) && connection_ids.is_a?(Hash) &&
        connection_ids.keys.all?(String) && connection_ids.keys.sort == Providers::Catalog::ROLES.keys.sort
    end
    private_class_method :valid_input?

    def self.resolve(role, value)
      return if value.blank?

      record = ProviderConnection.find_by(role: role, id: Integer(value.to_s, exception: false))
      raise Invalid, "Connexion introuvable pour ce rôle." unless record

      record.id
    end
    private_class_method :resolve
  end
end
