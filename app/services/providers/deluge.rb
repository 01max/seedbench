module Providers
  class Deluge
    def self.check(connection:)
      client = new(connection)
      client.authenticate!(connection.credentials.fetch("password"))
      client.connect!(connection.identity_key)

      CheckResult.new(status: "passed", code: "daemon_connected", message: "Authentification et connexion au démon vérifiées. Fichiers, recheck et seeding non testés.")
    end

    def authenticate!(password)
      raise Failure.new("authentication_failed", "Mot de passe Deluge refusé.") unless rpc("auth.login", [ password ]) == true
    end

    def connect!(identity)
      hosts = rpc("web.get_hosts")
      raise Failure.new("daemon_missing", "Le démon Deluge enregistré est absent; vérifiez son identifiant.") unless hosts.is_a?(Array) && hosts.any? { |host| host.is_a?(Array) && host.first == identity }

      rpc("web.connect", [ identity ])
      raise Failure.new("daemon_disconnected", "Le démon Deluge n’est pas connecté.") unless rpc("web.connected") == true
    end

    def initialize(connection)
      @endpoint = connection.endpoint
      @cookies = ""
      @sequence = 0
    end

    def rpc(method, parameters = [])
      @sequence += 1
      response = Http.call(endpoint: @endpoint, path: "/json", headers: { "Content-Type" => "application/json", "Cookie" => @cookies },
        body: { method: method, params: parameters, id: @sequence })
      @cookies = response.cookies unless response.cookies.empty?
      data = Http.json(response)
      raise Failure.new("rpc_failed", "Deluge a refusé la requête; vérifiez les droits et le démon.") unless data.is_a?(Hash) && data["id"] == @sequence && data["error"].nil? && data.key?("result")

      data["result"]
    end
  end
end
