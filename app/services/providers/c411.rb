module Providers
  class C411
    def self.check(connection:)
      response = Http.call(endpoint: connection.endpoint, path: "/api/user/drafts",
        headers: { "Authorization" => "Bearer #{connection.credentials.fetch('api_key')}" })
      data = Http.json(response)
      raise Failure.new("invalid_response", "La liste de brouillons n’a pas pu être vérifiée.") unless data.is_a?(Hash) && data["success"] == true && data["data"].is_a?(Array)

      CheckResult.new(status: "passed", code: "draft_list", message: "Lecture des brouillons autorisée. Publication et téléchargement non testés.")
    end
  end
end
