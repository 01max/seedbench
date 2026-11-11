require 'net/http'
require 'json'
require 'timeout'
require 'zlib'

module Providers
  class Http
    Response = Data.define(:body, :cookies)
    MAX_BYTES = 1_048_576

    class << self
      def call(endpoint:, path:, headers: {}, body: nil, form: nil, multipart: nil, redirects: 0, total_timeout: 10, read_timeout: 5, method: nil)
        uri = URI.parse(endpoint + path)
        request = request_for(uri, headers, body, form, multipart, method)
        Timeout.timeout(total_timeout) { execute(uri, request, redirects, read_timeout) }
      rescue Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, Zlib::Error
        raise Failure.new('invalid_response', I18n.t('messages.providers.http.reponse_http_illisible_du_fournisseur')), cause: nil
      rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
        raise Failure.new('network_error', I18n.t('messages.providers.http.connexion_impossible_ou_delai_depasse_verifiez')), cause: nil
      end

      def json(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Failure.new('invalid_response', I18n.t('messages.providers.http.reponse_json_illisible_du_fournisseur')), cause: nil
      end

      private

      def request_for(uri, headers, body, form, multipart, method)
        type = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }.fetch(method || ([ body, form, multipart ].any? ? :post : :get))
        request = type.new(uri)
        request['User-Agent'] = 'Seedbench/1.0'
        headers.each { |key, value| request[key] = value }
        request.body = JSON.generate(body) if body
        request.set_form_data(form) if form
        request.set_form(multipart, 'multipart/form-data') if multipart
        request
      end

      def execute(uri, request, redirects, read_timeout)
        http = Net::HTTP.new(uri.host, uri.port, nil)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 3
        http.read_timeout = http.write_timeout = read_timeout
        http.max_retries = 0
        http.start do |client|
          client.request(request) { |response| return resolve_response(uri, request, response, redirects, read_timeout) }
        end
      end

      def resolve_response(uri, request, response, redirects, read_timeout)
        return redirect(uri, request, response, redirects, read_timeout) if response.is_a?(Net::HTTPRedirection) && redirects.positive?

        read(response)
      end

      def redirect(uri, request, response, remaining, read_timeout)
        target = URI.join(uri, response['location'].to_s)
        raise Failure.new('invalid_redirect', I18n.t('messages.providers.http.redirection_du_catalogue_refusee')) unless request.is_a?(Net::HTTP::Get) && same_origin?(target, uri)

        redirected = Net::HTTP::Get.new(target)
        request.each_header { |key, value| redirected[key] = value }
        execute(target, redirected, remaining - 1, read_timeout)
      rescue URI::InvalidURIError
        raise Failure.new('invalid_redirect', I18n.t('messages.providers.http.redirection_du_catalogue_refusee')), cause: nil
      end

      def same_origin?(target, original)
        [ target.scheme, target.host, target.port ] == [ original.scheme, original.host, original.port ]
      end

      def read(response)
        raise Failure.new("http_#{response.code}", I18n.t('messages.providers.http.acces_refuse_ou_service_indisponible_http', status: response.code)) unless response.is_a?(Net::HTTPSuccess)

        body = +''
        response.read_body do |chunk|
          body << chunk
          raise Failure.new('response_too_large', I18n.t('messages.providers.http.reponse_du_fournisseur_trop_volumineuse')) if body.bytesize > MAX_BYTES
        end
        Response.new(body: body, cookies: cookies(response))
      end

      def cookies(response)
        response.get_fields('set-cookie').to_a.map { |cookie| cookie.split(';', 2).first }.join('; ')
      end
    end
  end
end
