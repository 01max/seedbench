module Providers
  class Openai
    def self.check(connection:)
      model = connection.options.fetch("model")
      response = Http.call(endpoint: connection.endpoint, path: "/v1/models/#{model}",
        headers: { "Authorization" => "Bearer #{connection.credentials.fetch('api_key')}" })
      data = Http.json(response)
      raise Failure.new("invalid_response", "Le modèle demandé n’a pas pu être vérifié.") unless data.is_a?(Hash) && data["id"] == model && data["object"] == "model"

      CheckResult.new(status: "passed", code: "model_read", message: "Accès au modèle vérifié. Génération et sorties structurées non testées.")
    end
  end
end
