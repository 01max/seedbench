require 'rails_helper'

RSpec.describe 'Selecting a Deluge daemon', type: :system do
  def open_deluge_form
    sign_in_browser
    visit settings_provider_path('torrent_client')
    click_button 'Deluge'
    fill_in 'Adresse du WebUI Deluge (sans /json)', with: 'http://deluge.test:8112'
    fill_in 'Mot de passe WebUI', with: 'entered-password'
  end

  it 'selects a single daemon automatically and saves its ID' do
    stub_deluge([ true, [ [ 'daemon-1', 'localhost', 58846, 'localclient' ] ], [], true ])
    open_deluge_form
    click_button 'Rechercher les démons'

    expect(page).to have_select('Démon Deluge', selected: 'localhost:58846 (localclient)')
    fill_in 'Libellé', with: 'Deluge local'
    click_button 'Tester la configuration'
    expect(page).to have_css('.settings-test-result[data-status="passed"]')
    click_button 'Enregistrer la connexion'

    expect(page).to have_css('article[aria-label="Deluge local"]')
    expect(ProviderConnection.sole.identity_key).to eq('daemon-1')
  end

  it 'lets the operator choose among several daemons and clears stale choices' do
    stub_deluge([ true, [ [ 'daemon-1', 'local', 58846 ], [ 'daemon-2', 'remote', 58846 ] ] ])
    open_deluge_form
    click_button 'Rechercher les démons'

    expect(page).to have_select('Démon Deluge', selected: 'Sélectionnez un démon', with_options: [ 'local:58846', 'remote:58846' ])
    select 'remote:58846', from: 'Démon Deluge'
    fill_in 'Mot de passe WebUI', with: 'different-password'
    expect(page).to have_select('Démon Deluge', options: [ 'Sélectionnez un démon' ])
  end
end
