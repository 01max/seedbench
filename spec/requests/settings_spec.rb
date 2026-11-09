require 'rails_helper'

RSpec.describe 'Provider settings' do
  before { sign_in_operator }

  it 'renders the four roles with masked secrets' do
    create_connection
    get settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('C411', 'Deluge', 'OpenAI', 'Postimages', '••••••••')
    expect(response.body).not_to include('synthetic-private-credential')
  end

  it 'creates a connection without making remote calls' do
    post provider_connections_path, params: { connection: connection_attributes }

    expect(response).to redirect_to(settings_path)
    expect(ProviderConnection.sole.check_status).to eq('untested')
  end

  it 'does not reflect rejected credentials into the response' do
    post provider_connections_path, params: { connection: connection_attributes.merge(options: { model: 'invalid' }) }
    follow_redirect!

    expect(response.body).to include('Options de connexion invalides')
    expect(response.body).not_to include('synthetic-private-credential')
    expect(ProviderConnection.count).to eq(0)
  end

  it 'rotates a secret only with explicit identity confirmation' do
    connection = create_connection
    patch rotate_provider_connection_path(connection), params: { rotation: { expected_version: 1, confirm_identity: '1', credentials: { api_key: 'new-private-value' } } }
    get settings_path

    expect(connection.reload.credentials).to eq('api_key' => 'new-private-value')
    expect(response.body).not_to include('new-private-value', 'synthetic-private-credential')
  end

  it 'runs an explicit sanitized connection test' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 403, body: 'private provider payload')
    post check_provider_connection_path(connection)
    follow_redirect!

    expect(response.body).to include('HTTP 403', 'échec')
    expect(response.body).not_to include('private provider payload', 'synthetic-private-credential')
  end

  it 'replaces a passing check with a sanitized protocol failure' do
    with_provider_http_response("upstream-private-marker\r\n\r\n") do |endpoint|
      connection = Settings::CreateConnection.call(**connection_attributes('torrent_client').merge(endpoint: endpoint))
      connection.update!(check_status: 'passed', check_code: 'daemon_connected', checked_at: 1.hour.ago)
      post check_provider_connection_path(connection)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Réponse HTTP illisible', 'échec')
      expect(response.body).not_to include('upstream-private-marker', 'synthetic-private-credential')
      expect(connection.reload.check_status).to eq('failed')
      expect(connection.check_code).to eq('invalid_response')
    end
  end

  it 'updates implemented AI options without changing the connection identity' do
    connection = create_connection('ai')
    patch configure_provider_connection_path(connection), params: { configuration: { expected_version: 1, options: { model: 'another-model' } } }

    expect(response).to redirect_to(settings_path)
    expect(connection.reload.options).to eq('model' => 'another-model')
  end

  it 'filters secrets from request diagnostics' do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    result = filter.filter({ credentials: { api_key: 'private' }, password: 'private', token: 'private' })

    expect(result.values).to all(eq('[FILTERED]'))
  end

  it 'saves defaults and preserves them when an older form arrives' do
    ids = Providers::Catalog::ROLES.keys.index_with { '' }
    patch settings_path, params: { defaults: { automatic_ai: '0', expected_revision: 0, connection_ids: ids } }
    expect(Settings::DefaultsSnapshot.call.automatic_ai).to be(false)
    patch settings_path, params: { defaults: { automatic_ai: '1', expected_revision: 0, connection_ids: ids } }
    follow_redirect!

    expect(response.body).to include('Les réglages ont changé')
    expect(Settings::DefaultsSnapshot.call.automatic_ai).to be(false)
  end
end
