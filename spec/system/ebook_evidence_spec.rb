require 'rails_helper'

RSpec.describe 'Ebook evidence review', type: :system do
  let(:release) { build_workbench_queue(count: 1).sole }
  let!(:evidence) do
    release.evidence_items.create!(payload_revision: release.payload_revisions.sole, evidence_key: 'embedded-title', kind: 'inspection',
      source: 'EPUB synthetic', captured_at: Time.current, input_revision: 0,
      data: { structure: { spine_documents: 2 }, candidates: [ { field: 'title', value: 'Embedded title', source: 'book.opf#title' } ],
        samples: [ { source: 'chapter.xhtml', text: 'Synthetic source text' } ] })
  end

  before do
    sign_in_browser
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
  end

  it 'saves pending prose before adopting a source-linked fact' do
    fill_in 'Présentation', with: 'Human prose retained during review'
    click_button 'Sources', exact: true
    click_button 'Adopter cette valeur'
    expect(page).to have_css('[data-evidence-revision="2"]')
    click_button 'Revue', exact: true
    expect(page).to have_field('Titre', with: 'Embedded title')
    expect(page).to have_field('Présentation', with: 'Human prose retained during review')
    expect(release.fact_evidence_links.sole.evidence_item).to eq(evidence)
    expect(release.content_revisions.where(kind: 'presentation').last.body).to eq('Human prose retained during review')
  end

  it 'refreshes source measurements without replacing dirty editor text' do
    click_button 'Sources', exact: true
    expect(page).to have_text('Synthetic source text')
    click_button 'Revue', exact: true
    delay_autosave_timer
    fill_in 'Présentation', with: 'Unsaved while sources refresh'
    click_button 'Sources', exact: true
    click_link 'Actualiser les sources'
    expect(page).to have_text('Synthetic source text')
    save_workbench_screenshot('evidence-review.png')
    click_button 'Revue', exact: true
    expect(page).to have_field('Présentation', with: 'Unsaved while sources refresh')
  end
end
