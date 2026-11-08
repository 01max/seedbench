module Providers
  class Postimages
    def self.check(**)
      response = Http.call(endpoint: "https://postimages.org", path: "/")
      raise Failure.new("invalid_response", "La page Postimages n’a pas pu être reconnue.") unless response.body.include?("postimages") || response.body.include?("Postimages")

      CheckResult.new(status: "limited", code: "reachability_only", message: "Site accessible. Clé et envoi non testés; aucune image envoyée.")
    end
  end
end
