require 'rails_helper'

RSpec.describe 'C411 draft review', type: :system do
  let(:release) { imported_draft }

  def open_draft
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
    click_button 'Brouillon', exact: true
  end

  before do
    release
    sign_in_browser
  end

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
    expect(page).to have_text('Résoudre le conflit')
    expect(page).to have_text('Copie humaine locale à conserver.')
    expect(page).to have_text('<script>alert(1)</script>Copie distante différente.')
    save_workbench_screenshot('draft-conflict-desktop.png')
    choose 'Conserver la copie locale pour un envoi ultérieur'
    click_button 'Confirmer ce choix'
    expect(page).to have_text('Choix enregistré localement')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'keeps the unlinked payload selection and confirmation accessible at mobile width' do
    target = Releases::Create.call(title: 'Livre distant')
    target.payload_revisions.create!(number: 1, original_filename: 'Synthetic.epub', format: 'epub', size_bytes: 42, sha256: 'a' * 64, locator: 'staging/synthetic.epub')
    open_draft
    set_workbench_viewport(320)
    find('summary', text: 'Lier un fichier importé').click
    expect(page).to have_text('Des titres proches sont proposés')
    expect(page.evaluate_script('document.documentElement.scrollWidth')).to be <= 320
    select "Proposition · ##{target.id} · Livre distant · Synthetic.epub", from: 'Fichier importé (100 résultats maximum par recherche)'
    check 'Je confirme que ce fichier correspond à ce brouillon.'
    save_workbench_screenshot('draft-link-mobile.png')
    click_button 'Confirmer le lien'
    expect(page).to have_current_path(release_path(target))
    expect(target.reload.draft_link.remote_id).to eq('draft-1')
  ensure
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end
end
