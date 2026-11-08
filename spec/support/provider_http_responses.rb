require "socket"
require "timeout"

module ProviderHttpResponses
  def with_provider_http_response(response)
    server = TCPServer.new("127.0.0.1", 0)
    responder = Thread.new do
      Timeout.timeout(3) do
        client = server.accept
        headers = []
        while (line = client.gets) && line != "\r\n"
          headers << line
        end
        length = headers.find { |header| header.match?(/\AContent-Length:/i) }.to_s.split(":", 2).last.to_i
        client.read(length) if length.positive?
        client.write(response)
      ensure
        client&.close
      end
    end
    yield "http://127.0.0.1:#{server.addr[1]}"
  ensure
    server&.close
    responder&.value
  end
end

RSpec.configure { |config| config.include ProviderHttpResponses }
