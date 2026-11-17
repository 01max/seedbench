require 'rails_helper'

RSpec.describe 'Provider settings', type: :system do
  it 'keeps provider navigation and forms usable on a narrow screen' do
    sign_in_browser
    visit settings_path
    save_workbench_screenshot('settings-dark.png')

    set_workbench_viewport(320)
    click_button 'Mode clair'
    within('nav.settings-sidebar') { click_link 'Services d’assistance IA' }
    expect(page).to have_current_path(settings_provider_path('ai'))
    click_button 'OpenAI'
    expect(page).to have_field('Identifiant exact du modèle')
    expect(page).to have_css('.settings-configuration-help', text: 'Aide à la configuration')
    expect(page.evaluate_script('document.documentElement.scrollWidth === document.documentElement.clientWidth')).to be(true)
    save_workbench_screenshot('settings-light-mobile.png')
    click_link 'Retour à l’atelier'
    expect(page).to have_current_path(root_path)
  end

  it 'returns to the tested connection and shows its result' do
    sign_in_browser
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [] }.to_json)
    visit settings_provider_path('publishing')
    click_button "Tester #{connection.label}"

    anchor = "provider_connection_#{connection.id}"
    location = settings_provider_path('publishing', anchor: anchor)
    expect(page).to have_current_path(/#{Regexp.escape(location)}\z/, url: true)
    expect(page).to have_css(%(##{anchor} .settings-status[data-status="passed"]), text: 'Test réussi')
  end

  it 'tests an unsaved OpenAI configuration and clears its result after an edit' do
    sign_in_browser
    stub_openai_connection_check(api_key: 'entered-test-key')
    visit settings_provider_path('ai')
    click_button 'OpenAI'
    fill_in 'Libellé', with: 'OpenAI de test'
    fill_in 'Identité stable du compte ou projet', with: 'test-project'
    fill_in 'Clé API', with: 'entered-test-key'
    fill_in 'Identifiant exact du modèle', with: 'synthetic-model'
    click_button 'Tester la configuration'

    expect(page).to have_css('.settings-test-result[data-status="passed"]', text: 'Le modèle configuré a renvoyé une réponse de test.')
    expect(ProviderConnection.count).to eq(0)
    fill_in 'Identifiant exact du modèle', with: 'different-model'
    expect(page).to have_no_css('.settings-test-result[data-status="passed"]')
  end

  it 'completes a legacy AI connection with its secret and model together' do
    sign_in_browser
    connection = ProviderConnection.create!(role: 'ai', provider: 'openai', identity_key: 'legacy-project', label: 'Legacy AI')
    visit settings_provider_path('ai')
    within("article[aria-label='Legacy AI']") do
      find('summary', text: 'Compléter la configuration').click
      expect(page).to have_css('.settings-configuration-help', text: 'Confirmation de l’identité')
      fill_in 'Clé API', with: 'completed-browser-secret'
      fill_in 'Identifiant exact du modèle', with: 'synthetic-model'
      check 'Je confirme la même identité de compte ou de démon.'
      click_button 'Compléter la connexion'
    end

    expect(page).to have_content('Configuration complétée')
    expect(connection.reload.options).to eq('model' => 'synthetic-model')
    expect(page.html).not_to include('completed-browser-secret')
  end

  it 'saves future defaults while keeping an existing release unchanged' do
    sign_in_browser
    release = Releases::Create.call
    connection = create_connection
    click_link 'Réglages'
    select connection.label, from: 'default_publishing'
    uncheck 'Premier passage IA automatique'
    click_button 'Enregistrer les choix par défaut'

    expect(page).to have_content('Les livres existants restent inchangés')
    expect(page).to have_unchecked_field('Premier passage IA automatique')
    expect(release.reload).to be_automatic_ai
    expect(release.provider_assignments.pluck(:provider_connection_id)).to all(be_nil)
  end

  it 'assigns an unconfigured role deliberately without revealing credentials' do
    sign_in_browser
    release = Releases::Create.call(title: 'Synthetic browser book')
    connection = create_connection
    visit release_connections_path(release)
    within('form#publishing_assignment') do
      select connection.label, from: 'Connexion à affecter'
      click_button 'Affecter à ce livre'
    end

    expect(page).to have_content('Connexion affectée explicitement')
    expect(page).to have_content(connection.identity_key)
    expect(page.html).not_to include('synthetic-private-credential')
  end

  it 'creates a masked connection from its provider-specific form' do
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [] }.to_json)
    sign_in_browser
    visit settings_provider_path('publishing')
    within("section[aria-labelledby='role-publishing']") do
      click_button 'C411'
      fill_in 'Libellé', with: 'Browser C411'
      fill_in 'Identité stable du compte ou projet', with: 'browser-account'
      fill_in 'Clé API', with: 'browser-private-credential'
      click_button 'Enregistrer la connexion'
    end

    expect(page).to have_content('Browser C411')
    expect(page).to have_content('•••••••• (configuré)')
    expect(page.html).not_to include('browser-private-credential')
  end
end
