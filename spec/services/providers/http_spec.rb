require 'rails_helper'

RSpec.describe Providers::Http do
  {
    'status line' => "upstream-private-marker\r\n\r\n",
    'chunked body' => "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nzzzzzz\r\nupstream-private-marker\r\n",
    'compressed body' => "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: 23\r\n\r\nupstream-private-marker"
  }.each do |part, response|
    it "sanitizes a malformed #{part} without retaining its raw exception" do
      with_provider_http_response(response) do |endpoint|
        expect { described_class.call(endpoint: endpoint, path: '/') }.to raise_error(Providers::Failure) do |error|
          expect(error.code).to eq('invalid_response')
          expect(error.message).not_to include('upstream-private-marker')
          expect(error.cause).to be_nil
        end
      end
    end
  end
end
