require 'rails_helper'

RSpec.describe 'Appearance', type: :system do
  it 'loads controls through Turbo and applies a Stimulus preference', :aggregate_failures do
    sign_in_browser
    page.execute_script("localStorage.setItem('seedbench.appearance', 'dark')")
    visit root_path
    page.execute_script("window.navigationMarker = 'retained'")
    click_link 'Apparence'

    expect(page).to have_css('turbo-frame#appearance [role="switch"]')
    expect(page.evaluate_script('window.navigationMarker')).to eq('retained')
    click_button 'Mode sombre'
    expect(page).to have_css('html[data-theme="light"]')
    expect(page).to have_css('[role="switch"][aria-checked="false"]')

    visit root_path
    expect(page).to have_css('html[data-theme="light"]')
    expect(page).to have_css('h1', text: 'Seedbench')
  end
end
