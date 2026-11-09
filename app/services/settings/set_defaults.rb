module Settings
  class SetDefaults
    class Invalid < StandardError; end
    class Conflict < StandardError; end

    class << self
      def call(automatic_ai:, connection_ids:, expected_revision:)
        raise Invalid, I18n.t('messages.settings.set_defaults.reglages_par_defaut_invalides') unless valid_input?(automatic_ai, connection_ids)

        OperatorPreference.transaction do
          preference = OperatorPreference.find_or_create_by!(id: 1)
          raise Conflict, I18n.t('messages.settings.set_defaults.les_reglages_ont_change_rechargez_la') unless preference.revision == expected_revision

          connection_ids.each { |role, id| ProviderDefault.find_or_initialize_by(role: role).update!(provider_connection_id: resolve(role, id)) }
          preference.update!(automatic_ai: automatic_ai, revision: preference.revision + 1)
        end
        DefaultsSnapshot.call
      end

      private

      def valid_input?(automatic_ai, connection_ids)
        [ true, false ].include?(automatic_ai) && connection_ids.is_a?(Hash) &&
          connection_ids.keys.all?(String) && connection_ids.keys.sort == Providers::Catalog::ROLES.keys.sort
      end

      def resolve(role, value)
        return if value.blank?

        record = ProviderConnection.find_by(role: role, id: Integer(value.to_s, exception: false))
        raise Invalid, I18n.t('messages.settings.set_defaults.connexion_introuvable_pour_ce_role') unless record

        record.id
      end
    end
  end
end
