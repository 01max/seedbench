require 'rails_helper'

RSpec.describe 'Workbench keyboard and large queues', type: :system do
  it 'searches and filters a queue larger than a page using actual authors and states' do
    books = build_workbench_queue(count: 85)
    books.last.update!(publication_state: 'published')
    sign_in_browser
    open_editor(books.first)
    click_link 'Page suivante', exact: true
    expect(page).to have_css('.queue-row', count: 40)
    fill_in 'Rechercher par titre ou auteur', with: 'Jules Verne'
    select 'Publiés', from: 'Filtrer la file'
    click_button 'Filtrer', exact: true

    expect(page).to have_css('.queue-row', count: 1)
    expect(page).to have_field('Titre', with: books.last.title)
    expect(page).to have_text('Publié')
  end

  it 'saves immediately with Ctrl S and keeps edits through Alt navigation' do
    books = build_workbench_queue(count: 2)
    sign_in_browser
    open_editor(books.first)
    delay_autosave_timer
    fill_in 'Présentation', with: 'Saved from the keyboard'
    find('#edit_presentation').send_keys([ :control, 's' ])
    expect(page).to have_css('#save-status', text: 'Enregistré')
    find('#edit_presentation').send_keys([ :alt, :arrow_down ])
    expect(page).to have_css(".work-main[data-release-id='#{books.last.id}']")
    find('#edit_title').send_keys([ :alt, :arrow_up ])
    expect(page).to have_field('Présentation', with: 'Saved from the keyboard')
    expect(PreparationRevision.count).to eq(0)
  end

  it 'saves immediately with Command S and keeps failure on the current release' do
    books = build_workbench_queue(count: 2)
    sign_in_browser
    open_editor(books.first)
    delay_autosave_timer
    fill_in 'Présentation', with: 'Command saved text'
    find('#edit_presentation').send_keys([ :meta, 's' ])
    expect(page).to have_css('#save-status', text: 'Enregistré')
    reject_editor_saves
    fill_in 'Présentation', with: 'Must stay on this book'
    find('#edit_presentation').send_keys([ :alt, :arrow_down ])
    expect(page).to have_text('Échec réseau synthétique')
    expect(page).to have_css(".work-main[data-release-id='#{books.first.id}']")
    expect(page).to have_field('Présentation', with: 'Must stay on this book')
  end

  it 'keeps tab selection and visible focus available from the keyboard' do
    book = build_workbench_queue(count: 1).sole
    sign_in_browser
    open_editor(book)
    find('#tab-review').send_keys(:arrow_right)

    expect(page).to have_css('#tab-bbcode[aria-selected="true"]')
    expect(page.evaluate_script('document.activeElement.id')).to eq('tab-bbcode')
    find('#tab-bbcode').send_keys(:end)
    expect(page).to have_css('#tab-preview[aria-selected="true"]')
    expect(page.evaluate_script('getComputedStyle(document.activeElement).outlineStyle')).not_to eq('none')
  end
end
