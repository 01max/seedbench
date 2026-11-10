require 'rails_helper'

RSpec.describe Covers::Fetch do
  before { allow(Resolv).to receive(:getaddresses).with('images.example').and_return([ '93.184.216.34' ]) }

  it 'fetches public HTTPS bytes with bounded redirects and no credentials' do
    stub_request(:get, 'https://images.example/start').to_return(status: 302, headers: { 'Location' => '/cover.png' })
    stub_request(:get, 'https://images.example/cover.png').to_return(body: 'image bytes', headers: { 'Content-Type' => 'image/png' })
    result = described_class.call(url: 'https://images.example/start')
    expect(result.bytes).to eq('image bytes')
    expect(result.url).to eq('https://images.example/cover.png')
    expect(WebMock).to(have_requested(:get, 'https://images.example/cover.png').with { |request| !request.headers.key?('Authorization') })
  end

  it 'rejects private, loopback, link-local, mapped and mixed DNS destinations' do
    [ '127.0.0.1', '10.0.0.1', '169.254.169.254', '::1', '::ffff:127.0.0.1', 'fc00::1' ].each do |address|
      allow(Resolv).to receive(:getaddresses).with('images.example').and_return([ '93.184.216.34', address ])
      expect { described_class.call(url: 'https://images.example/a') }.to raise_error(Covers::Failure, /Adresse refusée/)
    end
  end

  it 'refuses redirect rebinding, embedded credentials and insecure protocols' do
    stub_request(:get, 'https://images.example/start').to_return(status: 302, headers: { 'Location' => 'https://internal.example/cover' })
    allow(Resolv).to receive(:getaddresses).with('internal.example').and_return([ '192.168.1.1' ])
    expect { described_class.call(url: 'https://images.example/start') }.to raise_error(Covers::Failure)
    %w[file:///etc/passwd http://images.example/cover https://user:password@images.example/cover].each do |url|
      expect { described_class.call(url: url) }.to raise_error(Covers::Failure)
    end
  end

  it 'bounds response bytes and sanitizes inaccessible images' do
    stub_request(:get, 'https://images.example/large').to_return(body: '12345')
    expect { described_class.call(url: 'https://images.example/large', max_bytes: 4) }.to raise_error(Covers::Failure, /8 Mio/)
    stub_request(:get, 'https://images.example/private').to_return(status: 403, body: 'sensitive upstream response')
    expect { described_class.call(url: 'https://images.example/private') }.to raise_error(Covers::Failure, /Image inaccessible/)
  end
end
