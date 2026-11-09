require 'rails_helper'

RSpec.describe 'Release workspace', type: :system do
  it 'saves reversible manual marks without replacing the editor' do
    release = Releases::Create.call(title: 'Synthetic')
    sign_in_browser
    visit release_path(release)
    page.execute_script("document.querySelector('#edit_title').dataset.retained = 'yes'")
    within('[data-check-key="text_review"]') { check 'Texte relu' }
    expect(page).to have_css('[data-check-key="text_review"][data-check-state="done"]')
    within('[data-check-key="text_review"]') { uncheck 'Texte relu' }
    expect(page).to have_css('[data-check-key="text_review"][data-check-state="pending"]')
    expect(page).to have_css('#edit_title[data-retained="yes"]')
    expect(release.manual_checks.order(:number).pluck(:checked)).to eq([ true, false ])
  end

  it 'opens local content, source evidence and preview on demand' do
    release = build_release_graph
    release.content_revisions.create!(kind: 'presentation', number: 1, body: 'Preserved presentation', origin: 'human', input_revision: 0)
    sign_in_browser
    visit release_path(release)
    click_button 'BBCode', exact: true
    expect(page).to have_field('BBCode complet', with: 'Human text')
    click_button 'Sources', exact: true
    expect(page).to have_text('Synthetic uncertainty')
    click_button 'Aperçu', exact: true
    expect(page).to have_css('.local-preview', text: 'Preserved presentation')
  end
end
