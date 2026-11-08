module OperatorHelpers
  PASSWORD = "Synthetic operator password"

  def create_operator
    Operator.create!(id: 1, password: PASSWORD, password_confirmation: PASSWORD)
  end

  def sign_in_operator
    create_operator unless Operator.exists?
    post operator_session_path, params: { operator: { password: PASSWORD } }
  end

  def sign_in_browser
    create_operator
    visit new_operator_session_path
    fill_in "Mot de passe", with: PASSWORD
    click_button "Se connecter"
    expect(page).to have_button("Se déconnecter")
  end
end

RSpec.configure { |config| config.include OperatorHelpers }
