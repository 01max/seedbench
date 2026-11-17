require 'rails_helper'

RSpec.describe 'C411 draft review', type: :system do
  let(:release) { linked_draft }

  def open_draft
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
    click_button 'Brouillon', exact: true
  end

  before { sign_in_browser }

  it 'saves pending BBCode before an explicit update without sending it from navigation' do
    open_draft
    click_button 'BBCode', exact: true
    fill_in 'BBCode', with: 'Texte courant relu avant l’envoi explicite.'
    click_button 'Mettre à jour le brouillon C411'
    expect(page).to have_content('Envoi du brouillon demandé')
    expect(release.draft_writes.sole.request.dig('content', 'description')).to eq('Texte courant relu avant l’envoi explicite.')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'shows both copies safely and resolves to the reviewed local text without remote writes' do
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: 'Copie humaine locale à conserver.' })
    stub_draft_account(draft_data(description: '<script>alert(1)</script>Copie distante différente.'))
    open_draft
    click_button 'Synchroniser maintenant'
    expect(page).to have_text('Résoudre le conflit')
    expect(page).to have_text('Copie humaine locale à conserver.')
    expect(page).to have_text('<script>alert(1)</script>Copie distante différente.')
    save_workbench_screenshot('draft-conflict-desktop.png')
    choose 'Conserver la copie locale pour un envoi ultérieur'
    click_button 'Confirmer ce choix'
    expect(page).to have_text('Choix enregistré localement')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'keeps C411 imports in their own filter and restores them there from Archives' do
    imported = imported_draft
    set_workbench_viewport(320)
    visit root_path
    expect(page).to have_no_link('Livre distant')
    select 'Imports C411', from: 'Filtrer la file'
    expect(page).to have_css('.queue-row[aria-current="page"]', text: 'Import C411')
    expect(page.evaluate_script('document.documentElement.scrollWidth')).to be <= 320
    click_button 'Archiver'
    expect(page).to have_no_link('Livre distant')
    select 'Archives', from: 'Filtrer la file'
    click_button 'Restaurer'
    expect(page).to have_current_path(release_path(imported, state: 'imported')).and(have_css('.queue-row[aria-current="page"]', text: 'Import C411'))
  ensure
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end
end
