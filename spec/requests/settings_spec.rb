require 'rails_helper'

RSpec.describe 'Provider settings' do
  before { sign_in_operator }

  it 'shows only the selected provider connections and masks their secrets' do
    create_connection
    create_connection('ai')
    get settings_provider_path('publishing')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Synthetic C411', '••••••••')
    expect(response.body).not_to include('Synthetic OpenAI', 'synthetic-private-credential', 'Enregistrer les choix par défaut')
    expect(response.parsed_body.at_css('.settings-sidebar [aria-current="page"]').text.strip).to eq('Sites de publication')
  end

  it 'creates a connection and immediately imports drafts using read requests' do
    stub_draft_account
    post provider_connections_path, params: { connection: connection_attributes }

    expect(response).to redirect_to(settings_provider_path('publishing'))
    expect(ProviderConnection.sole.check_status).to eq('untested')
    expect(DraftLink.count).to eq(1)
  end

  it 'does not reflect rejected credentials into the response' do
    post provider_connections_path, params: { connection: connection_attributes.merge(options: { model: 'invalid' }) }
    expect(response).to redirect_to(settings_provider_path('publishing', provider: 'c411'))
    follow_redirect!

    expect(response.body).to include('Options de connexion invalides')
    expect(response.body).not_to include('synthetic-private-credential')
    expect(response.parsed_body.at_css('#provider-setup-c411 .settings-configuration-help')).to be_present
    expect(ProviderConnection.count).to eq(0)
  end

  { 'publishing' => /brouillons/, 'torrent_client' => /Rechercher les démons/, 'ai' => /API Responses/, 'image_host' => /32 caractères hexadécimaux/ }.each do |role, instruction|
    it "shows a logo and help for each #{role} input when its provider is selected" do
      definition = Providers::Catalog.fetch(role)
      get settings_provider_path(role)
      picker = response.parsed_body.at_css('.settings-provider-option')
      expect(picker).to have_attributes(text: a_string_including(definition.name))
      expect(picker.at_css('img')['src']).to match(%r{/providers/#{definition.provider}(?:-[0-9a-f]+)?\.svg\z})
      expect(response.parsed_body.at_css('.settings-configuration-help')).to be_nil

      get settings_provider_path(role, provider: definition.provider)
      panel = response.parsed_body.at_css("#provider-setup-#{definition.provider}")
      inputs = panel.css('.settings-field input, .settings-field select')
      expect(inputs.map { |input| panel.at_css("##{input['aria-describedby']}").text }).to include(a_string_matching(instruction))
      expect(panel.at_css('.translation_missing')).to be_nil
    end
  end

  it 'rotates a secret only with explicit identity confirmation' do
    connection = create_connection
    patch rotate_provider_connection_path(connection), params: { rotation: { expected_version: 1, confirm_identity: '1', credentials: { api_key: 'new-private-value' } } }
    follow_redirect!

    expect(connection.reload.credentials).to eq('api_key' => 'new-private-value')
    expect(response.body).not_to include('new-private-value', 'synthetic-private-credential')
  end

  it 'runs an explicit sanitized connection test' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 403, body: 'private provider payload')
    post check_provider_connection_path(connection)
    expect(response).to redirect_to(settings_provider_path('publishing', anchor: "provider_connection_#{connection.id}"))
    follow_redirect!

    expect(response.body).to include('HTTP 403', 'Échec du test')
    expect(response.body).not_to include('private provider payload', 'synthetic-private-credential')
  end

  it 'asks for a fresh test when the saved result only checked model access' do
    connection = create_connection('ai')
    connection.update!(check_status: 'passed', check_code: 'model_read', check_message: 'Legacy model check', checked_at: Time.current)
    get settings_provider_path('ai')

    expect(response.parsed_body.at_css('.settings-status')['data-status']).to eq('untested')
    expect(response.body).not_to include('Legacy model check')
  end

  it 'replaces a passing check with a sanitized protocol failure' do
    with_provider_http_response("upstream-private-marker\r\n\r\n") do |endpoint|
      connection = Settings::CreateConnection.call(**connection_attributes('torrent_client').merge(endpoint: endpoint))
      connection.update!(check_status: 'passed', check_code: 'daemon_connected', checked_at: 1.hour.ago)
      post check_provider_connection_path(connection)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Réponse HTTP illisible', 'Échec du test')
      expect(response.body).not_to include('upstream-private-marker', 'synthetic-private-credential')
      expect(connection.reload.check_status).to eq('failed')
      expect(connection.check_code).to eq('invalid_response')
    end
  end

  it 'updates implemented AI options without changing the connection identity' do
    connection = create_connection('ai')
    patch configure_provider_connection_path(connection), params: { configuration: { expected_version: 1, options: { model: 'another-model' } } }

    expect(response).to redirect_to(settings_provider_path('ai'))
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
