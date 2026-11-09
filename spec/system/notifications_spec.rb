require "rails_helper"

RSpec.describe "Notifications", type: :system do
  it "presents and dismisses login feedback without leaving an empty strip" do
    sign_in_browser

    expect(page).to have_css('.flash-message--success[role="status"]', text: "Connexion réussie")
    save_workbench_screenshot("notification-dark.png")
    click_link "Apparence"
    click_button "Mode sombre"
    save_workbench_screenshot("notification-light.png")
    set_workbench_viewport(390)
    save_workbench_screenshot("notification-mobile.png")
    click_button "Fermer la notification"

    expect(page).not_to have_css(".flash-stack")
    expect(page).to have_button("Importer des ebooks")
  end

  it "renders login errors as dismissible alerts" do
    create_operator
    visit new_operator_session_path
    fill_in "Mot de passe", with: "Incorrect synthetic password"
    click_button "Se connecter"

    expect(page).to have_css('.flash-message--error[role="alert"]', text: "Mot de passe incorrect")
    click_button "Fermer la notification"
    expect(page).not_to have_css(".flash-stack")
    expect(page).to have_field("Mot de passe")
  end
end
