require 'rails_helper'

RSpec.describe 'Duplicate candidate review', type: :system do
  let(:release) { reviewed_content_release }

  before do
    configure_duplicate_search(release)
    stub_duplicate_search
    search_duplicates(release)
    sign_in_browser
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
    click_button 'Doublons', exact: true
  end

  it 'reviews a possible match, preserves confirmation history and requires a reason to clear it' do
    within('.duplicate-candidate') do
      select 'Doublon confirmé — publication bloquée', from: 'Décision pour ce candidat'
      click_button 'Enregistrer la décision'
    end
    expect(page).to have_text('Doublon C411 déjà existant')
    within('.duplicate-candidate') do
      select 'Faux positif — motif obligatoire', from: 'Décision pour ce candidat'
      fill_in 'Motif (20 caractères minimum pour écarter un faux positif)', with: 'Édition différente après vérification manuelle de l’ISBN et du format.'
      click_button 'Enregistrer la décision'
    end
    expect(page).to have_text('Recherche et candidats revus pour les données actuelles.')
    expect(release.duplicate_decisions.order(:id).pluck(:decision)).to include('confirmed', 'false_positive')
    expect(WebMock).not_to have_requested(:post, %r{c411.org|postimage.org})
    save_workbench_screenshot('duplicate-review-desktop.png')
  end

  it 'associates each candidate label with its own review fields' do
    extra = duplicate_feed(title: 'Synthetic book PDF', hash: 'f' * 40)[/<item>.*?<\/item>/m]
    stub_duplicate_search(body: duplicate_feed.sub('</channel>', "#{extra}</channel>"))
    search_duplicates(release)
    click_link 'Actualiser les résultats'
    expect(page).to have_css('.duplicate-candidate', count: 2)
    within(all('.duplicate-candidate').last) do
      select 'Doublon confirmé — publication bloquée', from: 'Décision pour ce candidat'
      click_button 'Enregistrer la décision'
    end
    expect(page).to have_text('Doublon C411 déjà existant')
    expect(Duplicates::Assessment.new(release.reload).candidates.map(&:decision)).to eq(%w[likely confirmed])
  end

  it 'keeps long evidence and review controls within a narrow mobile viewport' do
    set_workbench_viewport(320)
    expect(page).to have_text('Édition numérique de test.')
    expect(page.evaluate_script('document.documentElement.scrollWidth')).to be <= 320
    expect(page).to have_button('Enregistrer la décision')
    save_workbench_screenshot('duplicate-review-mobile.png')
  ensure
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end
end
