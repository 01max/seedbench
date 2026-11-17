require 'rails_helper'

RSpec.describe Settings::TestConnection do
  it 'verifies C411 draft read scope without claiming publication' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').with(headers: { 'Authorization' => 'Bearer synthetic-private-credential' })
      .to_return(body: { success: true, data: [] }.to_json)
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_status).to eq('passed')
    expect(connection.check_message).to include('Publication et téléchargement non testés')
  end

  it 'requests a synthetic OpenAI response from the configured model' do
    connection = create_connection('ai')
    request = stub_openai_connection_check
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('response_received')
    expect(request).to have_been_requested.once
  end

  it 'does not pass an OpenAI response that contains no generated text' do
    connection = create_connection('ai')
    stub_request(:post, 'https://api.openai.com/v1/responses')
      .to_return(body: { id: 'resp_synthetic_check', model: 'synthetic-model', status: 'completed', output: [] }.to_json)
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('invalid_response')
  end

  it 'verifies a Postimages upload with its key and a synthetic PNG' do
    connection = create_connection('image_host')
    request = stub_request(:post, 'https://api.postimage.org/1/upload').with(body: hash_including('key' => 'a' * 32, 'type' => 'png'))
      .to_return(body: '<data success="1" status="200"><url>https://postimg.cc/abc123</url></data>')
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_status).to eq('passed')
    expect(connection.check_message).to include('https://postimg.cc/abc123')
    expect(request).to have_been_requested.once
  end

  it 'treats Postimages API errors as failures even when HTTP succeeds' do
    connection = create_connection('image_host')
    stub_request(:post, 'https://api.postimage.org/1/upload')
      .to_return(body: '<data success="0" status="403"><error>Private API error</error></data>')
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_status).to eq('failed')
    expect(connection.check_message).not_to include('Private API error')
  end

  it 'authenticates to Deluge and verifies the explicitly identified daemon' do
    connection = create_connection('torrent_client')
    stub_deluge([ true, [ [ 'synthetic-account', 'deluge', 58846, 'Online' ] ], [], true ])
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('daemon_connected')
    expect(WebMock).to have_requested(:post, 'http://deluge.test:8112/json').with(headers: { 'Cookie' => '_session_id=synthetic' }).times(3)
  end

  it 'reports Deluge password rejection without leaking raw protocol errors' do
    connection = create_connection('torrent_client')
    stub_deluge([ false, [], [], false ])
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('authentication_failed')
  end

  it 'distinguishes absent and disconnected Deluge daemons' do
    connection = create_connection('torrent_client')
    stub_deluge([ true, [], [], false ])
    described_class.call(connection_id: connection.id)
    expect(connection.reload.check_code).to eq('daemon_missing')
    stub_deluge([ true, [ [ 'synthetic-account' ] ], [], false ])
    described_class.call(connection_id: connection.id)
    expect(connection.reload.check_code).to eq('daemon_disconnected')
  end

  it 'sanitizes HTTP failures and refuses redirects' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 302, body: 'secret synthetic-private-credential', headers: { 'Location' => 'https://elsewhere.invalid/' })
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('http_302')
    expect(connection.check_message).not_to include('synthetic-private-credential', 'elsewhere')
    expect(WebMock).not_to have_requested(:get, 'https://elsewhere.invalid/')
  end

  it 'sanitizes network failures' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_raise(SocketError.new('synthetic-private-credential'))
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('network_error')
    expect(connection.check_message).not_to include('synthetic-private-credential')
  end

  it 'rejects invalid and oversized responses' do
    connection = create_connection
    [ 'invalid', { success: false, data: [] }.to_json, 'x' * (Providers::Http::MAX_BYTES + 1) ].each do |body|
      stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: body)
      described_class.call(connection_id: connection.id)
      expect(connection.reload.check_status).to eq('failed')
    end
  end

  it 'does not accept a check completed after credential rotation' do
    connection = create_connection
    allow(Providers::C411).to receive(:check) do
      Settings::RotateCredentials.call(connection_id: connection.id, expected_version: 1, confirm_identity: true, credentials: { api_key: 'new' })
      Providers::CheckResult.new(status: 'passed', code: 'draft_list', message: 'Old result')
    end
    expect { described_class.call(connection_id: connection.id) }.to raise_error(Settings::RotateCredentials::Conflict)
    expect(connection.reload.check_status).to eq('untested')
  end

  it 'reports metadata-only connections as unconfigured' do
    connection = ProviderConnection.create!(role: 'publishing', provider: 'c411', identity_key: 'missing', label: 'Missing')
    described_class.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('unconfigured')
  end
end
