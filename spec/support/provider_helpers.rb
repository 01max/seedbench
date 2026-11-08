module ProviderHelpers
  def connection_attributes(role = "publishing", identity: "synthetic-account")
    definition = Providers::Catalog.fetch(role)
    { role: role, label: "Synthetic #{definition.name}", identity_key: identity,
      endpoint: definition.endpoint || "http://deluge.test:8112",
      credentials: { definition.secret => role == "image_host" ? "a" * 32 : "synthetic-private-credential" },
      options: role == "ai" ? { "model" => "synthetic-model" } : {} }
  end

  def create_connection(role = "publishing", identity: "synthetic-account")
    Settings::CreateConnection.call(**connection_attributes(role, identity: identity))
  end
end

RSpec.configure { |config| config.include ProviderHelpers }
