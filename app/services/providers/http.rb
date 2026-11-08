require "net/http"
require "json"
require "timeout"

module Providers
  class Http
    Response = Data.define(:body, :cookies)
    MAX_BYTES = 1_048_576

    def self.call(endpoint:, path:, headers: {}, body: nil)
      uri = URI.parse(endpoint + path)
      request = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Seedbench/1.0"
      headers.each { |key, value| request[key] = value }
      request.body = JSON.generate(body) if body
      Timeout.timeout(10) { execute(uri, request) }
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise Failure.new("network_error", "Connexion impossible ou délai dépassé; vérifiez l’adresse, le réseau et TLS.")
    end

    def self.json(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Failure.new("invalid_response", "Réponse JSON illisible du fournisseur.")
    end

    def self.execute(uri, request)
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 3
      http.read_timeout = http.write_timeout = 5
      http.max_retries = 0
      http.start { |client| client.request(request) { |response| return read(response) } }
    end
    private_class_method :execute

    def self.read(response)
      raise Failure.new("http_#{response.code}", "Accès refusé ou service indisponible (HTTP #{response.code}); vérifiez les droits et le filtrage réseau.") unless response.is_a?(Net::HTTPSuccess)

      body = +""
      response.read_body do |chunk|
        body << chunk
        raise Failure.new("response_too_large", "Réponse du fournisseur trop volumineuse.") if body.bytesize > MAX_BYTES
      end
      Response.new(body: body, cookies: response.get_fields("set-cookie").to_a.map { |cookie| cookie.split(";", 2).first }.join("; "))
    end
    private_class_method :read
  end
end
