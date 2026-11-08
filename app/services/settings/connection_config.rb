module Settings
  class ConnectionConfig
    class Invalid < StandardError; end

    def self.call(role:, label:, identity_key:, endpoint: nil, credentials: {}, options: {})
      definition = Providers::Catalog::ROLES[role]
      raise Invalid, "Rôle, libellé ou identité de connexion invalide." unless definition && text?(label) && text?(identity_key)

      { role: role, provider: definition.provider, label: label, identity_key: identity_key,
        endpoint: endpoint_for(role, endpoint, definition), credentials: secrets(credentials, definition), options: options_for(role, options) }
    end

    def self.text?(value)
      value.is_a?(String) && value.strip.present? && value.length <= 120 && !value.match?(/[\r\n]/)
    end
    private_class_method :text?

    def self.endpoint_for(role, endpoint, definition)
      value = endpoint.presence || definition.endpoint
      uri = URI.parse(value.to_s)
      raise Invalid, "Adresse de connexion invalide; utilisez HTTP(S) sans secret ni paramètres dans l’URL." unless http_address?(uri)
      raise Invalid, "Ce fournisseur utilise son adresse officielle." if role != "torrent_client" && value != definition.endpoint

      value.delete_suffix("/")
    rescue URI::InvalidURIError
      raise Invalid, "Adresse de connexion invalide."
    end
    private_class_method :endpoint_for

    def self.http_address?(uri)
      %w[http https].include?(uri.scheme) && uri.host.present? && !uri.userinfo && !uri.query && !uri.fragment
    end
    private_class_method :http_address?

    def self.secrets(credentials, definition)
      raise Invalid, "Identifiants invalides." unless credentials.is_a?(Hash)

      values = credentials.stringify_keys
      secret = values[definition.secret]
      raise Invalid, "Renseignez uniquement le secret requis par ce fournisseur." unless values.keys == [ definition.secret ] && secret?(secret)
      raise Invalid, "La clé Postimages doit contenir 32 caractères hexadécimaux." if definition.provider == "postimages" && !secret.match?(/\A[0-9a-fA-F]{32}\z/)

      values
    end
    private_class_method :secrets

    def self.secret?(value)
      value.is_a?(String) && value.present? && value.bytesize <= 16_384 && !value.match?(/[[:cntrl:]]/)
    end
    private_class_method :secret?

    def self.options_for(role, options)
      raise Invalid, "Options de connexion invalides." unless options.is_a?(Hash)

      values = options.stringify_keys
      return {} if role != "ai" && values.empty?
      raise Invalid, "Options de connexion invalides." unless role == "ai" && values.keys == [ "model" ] && model?(values["model"])

      values
    end
    private_class_method :options_for

    def self.model?(value)
      value.is_a?(String) && value.match?(/\A[a-zA-Z0-9_.:-]{1,120}\z/)
    end
    private_class_method :model?
  end
end
