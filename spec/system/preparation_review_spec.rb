require 'rails_helper'

RSpec.describe 'Canonical payload review', type: :system do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }

  before do
    sign_in_browser
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
  end

  it 'reviews a proposed name before explicit preparation and refreshes verified results' do
    fill_in 'Langue', with: 'fr'
    click_button 'Suggérer un nom'
    expect(page).to have_field('Nom de release', with: 'Synthetic.book.Test.Author.FRENCH.[EPUB]-NOTAG')
    click_button 'Préparer', exact: true
    expect(page).to have_text('Préparation demandée')
    operation = release.workflow_operations.where(kind: 'preparation').sole
    Workflows::Execute.call(operation_id: operation.id)
    expect(page).to have_css('[data-check-key="preparation"][data-check-state="done"]', wait: 5)
    click_button 'Fichiers', exact: true
    expect(page).to have_text('Synthetic.book.Test.Author.FRENCH-NOTAG.epub')
    expect(page).not_to have_css('.save-conflict:not([hidden])')
    save_workbench_screenshot('canonical-preparation.png')
  end

  it 'retains newer dirty text when preparation completes' do
    fill_in 'Langue', with: 'fr'
    click_button 'Suggérer un nom'
    expect(page).to have_field('Nom de release', with: /FRENCH/)
    click_button 'Préparer', exact: true
    expect(page).to have_text('Préparation demandée')
    delay_autosave_timer
    fill_in 'Présentation', with: 'Texte humain non enregistré à conserver.'
    Workflows::Execute.call(operation_id: release.workflow_operations.where(kind: 'preparation').sole.id)
    expect(page).to have_css('.save-conflict:not([hidden])', wait: 5)
    expect(page).to have_field('Présentation', with: 'Texte humain non enregistré à conserver.')
    expect(release.content_revisions.where(kind: 'presentation')).to be_empty
  end
end
