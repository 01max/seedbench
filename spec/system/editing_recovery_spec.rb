require 'rails_helper'

RSpec.describe 'Editing races and recovery', type: :system do
  it 'saves text typed during an in-flight response before navigating' do
    first = Releases::Create.call(title: 'First')
    second = Releases::Create.call(title: 'Second')
    sign_in_browser
    open_editor(first)
    hold_first_save_response
    fill_in 'Présentation', with: 'First revision'
    click_button 'Enregistrer', exact: true
    find('#workbench[data-save-held="true"]')
    fill_in 'Présentation', with: 'Newest revision typed while saving'
    click_button 'Enregistrer et suivant'
    page.execute_script('window.releaseSavedResponse()')
    expect(page).to have_css(".work-main[data-release-id='#{second.id}']")
    expect(first.content_revisions.where(kind: 'presentation').order(:number).last.body).to eq('Newest revision typed while saving')
  end

  it 'retains entered text and selection when filtering cannot save' do
    first = Releases::Create.call(title: 'First')
    Releases::Create.call(title: 'Second')
    sign_in_browser
    open_editor(first)
    reject_editor_saves
    fill_in 'Présentation', with: 'Preserved despite network failure'
    fill_in 'Rechercher par titre ou auteur', with: 'Second'
    click_button 'Filtrer', exact: true

    expect(page).to have_text('Échec réseau synthétique')
    expect(page).to have_field('Présentation', with: 'Preserved despite network failure')
    expect(page).to have_css(".work-main[data-release-id='#{first.id}']")
  end

  it 'restores text after reload and requires a choice when the saved revision changed' do
    release = Releases::Create.call(title: 'Original')
    sign_in_browser
    open_editor(release)
    reject_editor_saves
    fill_in 'Présentation', with: 'Recoverable draft'
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { title: 'New server title' })
    page.refresh
    expect(page).to have_field('Présentation', with: 'Recoverable draft')
    expect(page).to have_text('Votre saisie est conservée')
    click_button 'Charger le texte enregistré'
    expect(page).to have_field('Titre', with: 'New server title')
    page.refresh
    expect(page).to have_field('Présentation', with: '')
  end

  it 'does not let a delayed status response revert a newer manual review' do
    release = Releases::Create.call(title: 'Synthetic')
    release.workflow_operations.create!(kind: 'synthetic', request_key: 'pending', effect: 'local', input_revision: 0)
    sign_in_browser
    open_editor(release)
    hold_first_status_response
    find('#workbench[data-status-held="true"]', wait: 5)
    within('[data-check-key="text_review"]') { check 'Texte relu' }
    expect(page).to have_css('[data-check-key="text_review"][data-check-state="done"]')
    page.execute_script('window.releaseStatusResponse()')
    find('turbo-frame[data-delayed-status-handled="true"]')
    expect(page).to have_checked_field('Texte relu')
    expect(release.manual_checks.sole.checked).to be(true)
  end
end
