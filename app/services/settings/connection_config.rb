module Settings
  class ConnectionConfig
    class Invalid < StandardError; end

    class << self
      def call(role:, label:, identity_key:, endpoint: nil, credentials: {}, options: {})
        definition = Providers::Catalog::ROLES[role]
        raise Invalid, I18n.t('messages.settings.connection_config.role_libelle_ou_identite_de_connexion') unless definition && text?(label) && text?(identity_key)

        { role: role, provider: definition.provider, label: label, identity_key: identity_key,
          endpoint: endpoint_for(role, endpoint, definition), credentials: secrets(credentials, definition), options: options_for(role, options) }
      end

      private

      def text?(value)
        value.is_a?(String) && value.strip.present? && value.length <= 120 && !value.match?(/[\r\n]/)
      end

      def endpoint_for(role, endpoint, definition)
        value = endpoint.presence || definition.endpoint
        uri = URI.parse(value.to_s)
        raise Invalid, I18n.t('messages.settings.connection_config.adresse_de_connexion_invalide_utilisez_http') unless http_address?(uri)
        raise Invalid, I18n.t('messages.settings.connection_config.ce_fournisseur_utilise_son_adresse_officielle') if role != 'torrent_client' && value != definition.endpoint

        value.delete_suffix('/')
      rescue URI::InvalidURIError
        raise Invalid, I18n.t('messages.settings.connection_config.adresse_de_connexion_invalide')
      end

      def http_address?(uri)
        %w[http https].include?(uri.scheme) && uri.host.present? && !uri.userinfo && !uri.query && !uri.fragment
      end

      def secrets(credentials, definition)
        raise Invalid, I18n.t('messages.settings.connection_config.identifiants_invalides') unless credentials.is_a?(Hash)

        values = credentials.stringify_keys
        secret = values[definition.secret]
        raise Invalid, I18n.t('messages.settings.connection_config.renseignez_uniquement_le_secret_requis_par') unless values.keys == [ definition.secret ] && secret?(secret)
        raise Invalid, I18n.t('messages.settings.connection_config.la_cle_postimages_doit_contenir_32') if definition.provider == 'postimages' && !secret.match?(/\A[0-9a-fA-F]{32}\z/)

        values
      end

      def secret?(value)
        value.is_a?(String) && value.present? && value.bytesize <= 16_384 && !value.match?(/[[:cntrl:]]/)
      end

      def options_for(role, options)
        raise Invalid, I18n.t('messages.settings.connection_config.options_de_connexion_invalides') unless options.is_a?(Hash)

        values = options.stringify_keys
        return {} if role != 'ai' && values.empty?
        raise Invalid, I18n.t('messages.settings.connection_config.options_de_connexion_invalides') unless role == 'ai' && values.keys == [ 'model' ] && model?(values['model'])

        values
      end

      def model?(value)
        value.is_a?(String) && value.match?(/\A[a-zA-Z0-9_.:-]{1,120}\z/)
      end
    end
  end
end
