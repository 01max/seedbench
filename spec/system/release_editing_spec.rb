require 'rails_helper'

RSpec.describe 'Local editing', type: :system do
  it 'autosaves complete text and preserves it through Save and next navigation' do
    first = Releases::Create.call(title: 'First book')
    second = Releases::Create.call(title: 'Second book')
    sign_in_browser
    visit release_path(first)
    fill_in 'Présentation', with: 'Human presentation kept in full'
    expect(page).to have_css('#save-status', text: 'Enregistré')
    expect(first.content_revisions.where(kind: 'presentation').last.body).to eq('Human presentation kept in full')
    fill_in 'Titre', with: 'Reviewed first book'
    click_button 'Enregistrer et suivant'
    expect(page).to have_css('.work-main[data-release-id="' + second.id.to_s + '"]')
    click_link 'Précédent', exact: true
    expect(page).to have_field('Présentation', with: 'Human presentation kept in full')
    expect(page).to have_field('Titre', with: 'Reviewed first book')
  end

  it 'keeps entered text and the current book when saving fails validation' do
    first = Releases::Create.call(title: 'First book')
    Releases::Create.call(title: 'Second book')
    sign_in_browser
    visit release_path(first)
    fill_in 'Présentation', with: 'Still here'
    fill_in 'Titre', with: ''
    click_button 'Enregistrer et suivant'

    expect(page).to have_text('Le titre est requis')
    expect(page).to have_field('Présentation', with: 'Still here')
    expect(page).to have_css('.work-main[data-release-id="' + first.id.to_s + '"]')
  end

  it 'shows a concurrent save and retains the entered text until an explicit choice' do
    release = Releases::Create.call(title: 'Original title')
    sign_in_browser
    visit release_path(release)
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { title: 'Newer server title' })
    fill_in 'Titre', with: 'Entered title'
    click_button 'Enregistrer', exact: true
    expect(page).to have_text('Votre saisie est conservée')
    expect(page).to have_field('Titre', with: 'Entered title')
    click_button 'Enregistrer ma saisie à la place'
    expect(page).to have_css('#save-status', text: 'Enregistré')
    expect(release.reload.title).to eq('Entered title')
  end
end
