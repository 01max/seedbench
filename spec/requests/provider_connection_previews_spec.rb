require 'rails_helper'

RSpec.describe 'Provider connection previews' do
  def preview(role)
    post preview_provider_connections_path, params: { connection: connection_attributes(role) }, as: :json
  end

  it 'requires an operator session' do
    post preview_provider_connections_path, params: { connection: connection_attributes }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'checks the entered C411 key without creating a connection or importing drafts' do
    sign_in_operator
    request = stub_request(:get, 'https://c411.org/api/user/drafts').with(headers: { 'Authorization' => 'Bearer synthetic-private-credential' })
      .to_return(body: { success: true, data: [ {} ] }.to_json)
    preview('publishing')

    expect(response.parsed_body).to include('status' => 'passed', 'code' => 'draft_list')
    expect(request).to have_been_requested.once
    expect(ProviderConnection.count).to eq(0)
    expect(DraftLink.count).to eq(0)
  end

  it 'checks the entered Deluge settings without switching the WebUI daemon' do
    sign_in_operator
    stub_deluge([ true, [ [ 'synthetic-account' ] ] ])
    preview('torrent_client')

    expect(response.parsed_body).to include('status' => 'passed', 'code' => 'daemon_listed')
    expect(WebMock).to have_requested(:post, 'http://deluge.test:8112/json')
      .with(body: hash_including('method' => 'auth.login', 'params' => [ 'synthetic-private-credential' ])).once
    expect(WebMock).not_to have_requested(:post, 'http://deluge.test:8112/json').with(body: hash_including('method' => 'web.connect'))
    expect(ProviderConnection.count).to eq(0)
  end

  it 'sends the entered Postimages key and accepts a test image page' do
    sign_in_operator
    image = Base64.strict_encode64(Providers::Postimages::TEST_PNG)
    stub_request(:post, 'https://api.postimage.org/1/upload').with(body: hash_including('key' => 'a' * 32, 'image' => image))
      .to_return(body: '<data success="1" status="200"><url>https://postimg.cc/abc123</url></data>')
    preview('image_host')

    expect(response.parsed_body).to include('status' => 'passed', 'code' => 'test_image_uploaded')
    expect(ProviderConnection.count).to eq(0)
  end

  it 'uses the saved OpenAI key with the entered model without replacing the saved model' do
    sign_in_operator
    connection = create_connection('ai')
    stub_openai_connection_check(model: 'new-synthetic-model')
    post preview_provider_connection_path(connection, kind: 'configuration'),
      params: { configuration: { options: { model: 'new-synthetic-model' } } }, as: :json

    expect(response.parsed_body).to include('status' => 'passed', 'code' => 'response_received')
    expect(connection.reload).to have_attributes(options: { 'model' => 'synthetic-model' }, check_status: 'untested', credentials_version: 1)
  end

  it 'tests a replacement secret without rotating it or reflecting errors from the provider' do
    sign_in_operator
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').with(headers: { 'Authorization' => 'Bearer replacement-secret' })
      .to_return(status: 401, body: 'replacement-secret upstream-private-details')
    post preview_provider_connection_path(connection, kind: 'rotation'), params: { rotation: { credentials: { api_key: 'replacement-secret' } } }, as: :json

    expect(response.parsed_body).to include('status' => 'failed', 'code' => 'http_401')
    expect(response.body).not_to include('replacement-secret', 'upstream-private-details')
    expect(connection.reload).to have_attributes(credentials: { 'api_key' => 'synthetic-private-credential' }, check_status: 'untested', credentials_version: 1)
  end

  it 'tests legacy completion fields before saving them' do
    sign_in_operator
    connection = ProviderConnection.create!(role: 'ai', provider: 'openai', identity_key: 'legacy-model', label: 'Legacy AI')
    stub_openai_connection_check(api_key: 'completion-secret')
    post preview_provider_connection_path(connection, kind: 'completion'),
      params: { completion: { credentials: { api_key: 'completion-secret' }, options: { model: 'synthetic-model' } } }, as: :json

    expect(response.parsed_body).to include('status' => 'passed', 'code' => 'response_received')
    expect(connection.reload).to be_configuration_incomplete
  end

  it 'rejects invalid input before contacting the API' do
    sign_in_operator
    attributes = connection_attributes('ai').merge(options: { model: '../../wrong' })
    post preview_provider_connections_path, params: { connection: attributes }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include('status' => 'failed')
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/responses')
  end

  it 'reports omitted required connection fields without contacting the API' do
    sign_in_operator
    attributes = connection_attributes('ai').except(:label, :identity_key)
    post preview_provider_connections_path, params: { connection: attributes }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include('status' => 'failed', 'message' => I18n.t('messages.settings.connection_config.role_libelle_ou_identite_de_connexion'))
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/responses')
  end
end
