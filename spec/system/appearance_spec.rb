require 'rails_helper'

RSpec.describe 'Appearance', type: :system do
  it 'switches directly between labelled themes and remembers the choice across navigation', :aggregate_failures do
    sign_in_browser

    expect(page).to have_css('html[data-theme="dark"]')
    expect(find_button('Mode clair')).to have_css('svg')
    click_button 'Mode clair'
    expect(page).to have_css('html[data-theme="light"]')
    expect(find_button('Mode sombre')).to have_css('svg')

    click_link 'Réglages'
    expect(page).to have_button('Mode sombre')

    visit root_path
    expect(page).to have_css('html[data-theme="light"]')
    click_button 'Mode sombre'
    expect(page).to have_css('html[data-theme="dark"]')
    expect(page).to have_button('Mode clair')
  end
end
