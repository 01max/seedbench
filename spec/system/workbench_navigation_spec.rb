require 'rails_helper'

RSpec.describe 'Workbench keyboard and large queues', type: :system do
  it 'searches and filters a queue larger than a page using actual authors and states' do
    books = build_workbench_queue(count: 85)
    books.last.update!(publication_state: 'published')
    sign_in_browser
    open_editor(books.first)
    find('body').send_keys([ :alt, :page_down ])
    expect(page).to have_css('.queue-pagination', text: '2 / 3').and(have_css('.queue-row', count: 40))
    fill_in 'Rechercher par titre ou auteur', with: 'Jules Verne'
    select 'Publiés', from: 'Filtrer la file'

    expect(page).to have_css('.queue-row', count: 1)
    expect(page).to have_field('Titre', with: books.last.title)
    expect(page).to have_text('Publié')
  end

  it 'searches without a submit button and preserves focus and the cursor across results' do
    Releases::Create.call(title: 'Local book')
    Releases::Create.call(title: 'Plum tart')
    Releases::Create.call(title: 'Plum jam')
    sign_in_browser
    visit root_path
    find('body').send_keys('/')
    expect(page).to have_css('input[name="q"]:focus')

    find_field('Rechercher par titre ou auteur').send_keys('Plum ')
    expect(page).to have_css('.queue-row', count: 2).and(have_field('Rechercher par titre ou auteur', with: 'Plum '))
    find('input[name="q"]:focus').send_keys('jam')
    expect(page).to have_css('.queue-row', count: 1).and(have_css('.queue-title', text: 'Plum jam'))
    expect(page).to have_no_button('Filtrer')
  end

  it 'keeps a newer search when earlier results arrive while the operator is typing' do
    Releases::Create.call(title: 'Plum tart')
    Releases::Create.call(title: 'Plum jam')
    sign_in_browser
    visit root_path
    hold_first_search_response
    fill_in 'Rechercher par titre ou auteur', with: 'Plum'
    find('.queue-search[data-response-held="true"]')

    page.execute_script(<<~JS)
      const search = document.querySelector('input[name="q"]')
      search.value = 'Plum jam'
      search.dispatchEvent(new Event('input', { bubbles: true }))
      window.releaseQueueResponse()
    JS
    expect(page).to have_css('.queue-row', count: 1).and(have_css('.queue-title', text: 'Plum jam'))
  end

  it 'opens its keyboard shortcut sheet by key or by button, even on an empty queue' do
    sign_in_browser
    visit root_path
    find('body').send_keys('?')
    expect(page).to have_css('dialog[open]', text: 'Livre suivant dans la file')
    find_button('Fermer').send_keys(:escape)
    expect(page).to have_no_css('dialog[open]')

    click_button 'Raccourcis clavier'
    expect(page).to have_css('dialog[open]', text: 'Placer le curseur dans la recherche')
    click_button 'Fermer'
    expect(page).to have_no_css('dialog[open]')
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

  def hold_first_search_response
    page.execute_script(<<~JS)
      const fetchPage = window.fetch.bind(window)
      window.fetch = async (input, options) => {
        const response = await fetchPage(input, options)
        const url = new URL(input instanceof Request ? input.url : input, location.href)
        if (url.searchParams.get('q') === 'Plum') {
          document.querySelector('.queue-search').dataset.responseHeld = 'true'
          await new Promise(resolve => { window.releaseQueueResponse = resolve })
        }
        return response
      }
    JS
  end
end
