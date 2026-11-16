module Providers
  # Maps provider roles to their configuration requirements and connection-check adapters.
  class Catalog
    Definition = Data.define(:provider, :name, :endpoint, :secret)
    ROLES = {
      'publishing' => Definition.new(provider: 'c411', name: 'C411', endpoint: 'https://c411.org', secret: 'api_key'),
      'torrent_client' => Definition.new(provider: 'deluge', name: 'Deluge', endpoint: nil, secret: 'password'),
      'ai' => Definition.new(provider: 'openai', name: 'OpenAI', endpoint: 'https://api.openai.com', secret: 'api_key'),
      'image_host' => Definition.new(provider: 'postimages', name: 'Postimages', endpoint: 'https://api.postimage.org', secret: 'api_key')
    }.freeze

    def self.fetch(role)
      ROLES.fetch(role) { raise ArgumentError, I18n.t('messages.providers.catalog.role_de_fournisseur_inconnu') }
    end

    def self.adapter(connection)
      { 'publishing' => C411, 'torrent_client' => Deluge, 'ai' => Openai, 'image_host' => Postimages }.fetch(connection.role)
    end
  end
end
