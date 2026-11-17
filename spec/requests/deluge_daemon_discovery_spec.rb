require 'rails_helper'

RSpec.describe 'Deluge daemon discovery' do
  def discover(endpoint: 'http://deluge.test:8112')
    post discover_deluge_provider_connections_path, params: { connection: { endpoint: endpoint, credentials: { password: 'discovery-password' } } }, as: :json
  end

  it 'requires an operator session' do
    discover

    expect(response).to have_http_status(:unauthorized)
  end

  it 'uses the WebUI session to list daemons without storing or connecting to one' do
    sign_in_operator
    stub_deluge([ true, [ [ 'daemon-1', 'localhost', 58846, 'localclient', 'private-daemon-password' ] ] ])
    discover(endpoint: 'http://deluge.test:8112/')

    expect(response.parsed_body).to eq('daemons' => [ { 'id' => 'daemon-1', 'address' => 'localhost', 'port' => 58846, 'username' => 'localclient' } ])
    expect(WebMock).to have_requested(:post, 'http://deluge.test:8112/json')
      .with(headers: { 'Cookie' => '_session_id=synthetic' }, body: hash_including(method: 'web.get_hosts')).once
    expect(WebMock).not_to have_requested(:post, 'http://deluge.test:8112/json').with(body: hash_including(method: 'web.connect'))
    expect(ProviderConnection.count).to eq(0)
  end

  it 'reports an incorrect WebUI password without listing daemons' do
    sign_in_operator
    stub_deluge([ false ])
    discover

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch('message')).to eq('Mot de passe Deluge refusé.')
    expect(WebMock).not_to have_requested(:post, 'http://deluge.test:8112/json').with(body: hash_including(method: 'web.get_hosts'))
  end

  it 'rejects invalid endpoints before sending the WebUI password' do
    sign_in_operator
    discover(endpoint: 'http://user@deluge.test:8112')

    expect(response).to have_http_status(:unprocessable_content)
  end
end
