module OperatorHelpers
  PASSWORD = "Synthetic operator password"

  def create_operator
    Operator.create!(id: 1, password: PASSWORD, password_confirmation: PASSWORD)
  end

  def sign_in_operator
    create_operator unless Operator.exists?
    post session_path, params: { password: PASSWORD }
  end

  def sign_in_browser
    create_operator
    visit new_session_path
    fill_in "Mot de passe", with: PASSWORD
    click_button "Se connecter"
    expect(page).to have_button("Se déconnecter")
  end
end

RSpec.configure { |config| config.include OperatorHelpers }
