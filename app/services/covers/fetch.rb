require 'net/http'
require 'timeout'

module Covers
  class Fetch
    Result = Data.define(:bytes, :media_type, :url)
    MAX_BYTES = 8 * 1024 * 1024

    def self.call(url:, max_bytes: MAX_BYTES, hosts: nil)
      new(max_bytes, hosts).call(url)
    end

    def initialize(max_bytes, hosts)
      @max_bytes, @hosts = max_bytes, hosts
    end

    def call(url)
      raise Failure.new(:unsafe_url) unless url.is_a?(String) && url.bytesize <= 4096

      Timeout.timeout(20) { fetch(url, 2) }
    rescue URI::InvalidURIError, SocketError, Resolv::ResolvError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError
      raise Failure.new(:fetch_failed), cause: nil
    end

    private

    def fetch(url, redirects)
      uri = URI.parse(url)
      validate_url!(uri, url)
      http = client(uri)
      http.start do |connection|
        connection.request(Net::HTTP::Get.new(uri, 'User-Agent' => 'Seedbench/1.0')) do |response|
          return resolve(response, uri, redirects)
        end
      end
    end

    def validate_url!(uri, url)
      raise Failure.new(:unsafe_url) unless secure_url?(uri) && !url.match?(/[\s\x00-\x1f\x7f]/)
      raise Failure.new(:unsafe_url) if @hosts && @hosts.exclude?(uri.host)
    end

    def secure_url?(uri)
      uri.scheme == 'https' && uri.host.present? && uri.userinfo.nil? && uri.port == 443 && uri.fragment.nil?
    end

    def client(uri)
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.ipaddr = PublicAddress.call(host: uri.host)
      http.use_ssl = true
      http.open_timeout = 3
      http.read_timeout = http.write_timeout = 5
      http.max_retries = 0
      http
    end

    def resolve(response, uri, redirects)
      if response.is_a?(Net::HTTPRedirection)
        raise Failure.new(:unsafe_url) unless redirects.positive?

        return fetch(URI.join(uri, response['location'].to_s).to_s, redirects - 1)
      end
      raise Failure.new(:fetch_failed) unless response.is_a?(Net::HTTPSuccess)

      Result.new(bytes: read(response), media_type: response.content_type.to_s, url: uri.to_s)
    end

    def read(response)
      bytes = +''.b
      response.read_body do |chunk|
        bytes << chunk.b
        raise Failure.new(:too_large) if bytes.bytesize > @max_bytes
      end
      bytes
    end
  end
end
