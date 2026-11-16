require 'rails_helper'

RSpec.describe 'Release archive', type: :system do
  it 'saves pending edits, moves a book out of the queue, and restores it from Archives' do
    sign_in_browser
    release = Releases::Create.call(title: 'Book to archive')
    Releases::Create.call(title: 'Next book')
    open_editor(release)

    fill_in 'Titre', with: 'Reviewed archive title'
    click_button 'Archiver'

    expect(page).to have_css('[role="status"]', text: '« Reviewed archive title » a été archivé.')
    expect(page).to have_css('.queue-row[aria-current="page"]', text: 'Next book')
    expect(page).to have_no_link('Reviewed archive title')

    select 'Archives', from: 'Filtrer la file'
    click_button 'Filtrer'
    expect(page).to have_css('.queue-row[aria-current="page"]', text: /Reviewed archive title.*Archivé/m)
    click_button 'Restaurer'

    expect(page).to have_css('.queue-row[aria-current="page"]', text: 'Reviewed archive title')
  end

  it 'keeps the current queue page while it still has books' do
    sign_in_browser
    Releases::Create.call(title: 'First book')
    (Releases::Queue::PAGE_SIZE - 1).times { Releases::Create.call }
    release = Releases::Create.call(title: 'First book on page two')
    Releases::Create.call(title: 'Last book on page two')
    open_editor(release)

    click_button 'Archiver'
    expect(page).to have_css('.queue-row[aria-current="page"]', text: 'Last book on page two')
    expect(page).to have_css('.queue-pagination', text: '2 / 2')

    click_button 'Archiver'
    expect(page).to have_css('.queue-row[aria-current="page"]', text: 'First book')
    expect(page).to have_no_css('.queue-pagination')
  end
end
