require 'rails_helper'

RSpec.describe 'Ebook content review', type: :system do
  let(:release) { reviewed_content_release }

  before do
    sign_in_browser
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
  end

  it 'saves pending prose before proposing and requires explicit acceptance' do
    fill_in 'Présentation', with: 'Prose humaine conservée dans la proposition.'
    click_button 'Proposer le BBCode'
    expect(page).to have_css('.content-proposal[open]', text: 'Prose humaine conservée')
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq('Human text')
    click_button 'Accepter cette proposition'
    click_button 'BBCode', exact: true
    expect(page).to have_field('BBCode complet', with: /Prose humaine conservée/)
    expect(page).to have_css('[data-content-kind="bbcode"][data-content-state="ready"]')
  end

  it 'preserves newer full manual BBCode when an older proposal is accepted' do
    click_button 'Proposer le BBCode'
    expect(page).to have_css('.content-proposal[open]')
    click_button 'BBCode', exact: true
    fill_in 'BBCode complet', with: 'Texte manuel plus récent'
    click_button 'Accepter cette proposition'
    expect(page).to have_text('Le texte ou ses faits ont changé')
    expect(page).to have_field('BBCode complet', with: 'Texte manuel plus récent')
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq('Texte manuel plus récent')
  end

  it 'previews unsaved BBCode without executing active content or saving it' do
    delay_autosave_timer
    click_button 'BBCode', exact: true
    fill_in 'BBCode complet', with: '[center][b]Aperçu inédit[/b][/center]<script>window.previewAttack=true</script>'
    click_button 'Aperçu', exact: true
    expect(page).to have_css('.rendered-bbcode .bb-center strong', text: 'Aperçu inédit')
    expect(page).not_to have_css('.rendered-bbcode script', visible: :all)
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq('Human text')
    save_workbench_screenshot('content-preview.png')
  end
end
