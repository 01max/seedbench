require "rails_helper"

RSpec.describe "Provider settings", type: :system do
  it "completes a legacy AI connection with its secret and model together" do
    sign_in_browser
    connection = ProviderConnection.create!(role: "ai", provider: "openai", identity_key: "legacy-project", label: "Legacy AI")
    visit settings_path
    within("article[aria-label='Legacy AI']") do
      find("summary", text: "Compléter la configuration").click
      fill_in "Clé API", with: "completed-browser-secret"
      fill_in "Identifiant exact du modèle", with: "synthetic-model"
      check "Je confirme la même identité de compte ou de démon."
      click_button "Compléter la connexion"
    end

    expect(page).to have_content("Configuration complétée")
    expect(connection.reload.options).to eq("model" => "synthetic-model")
    expect(page.html).not_to include("completed-browser-secret")
  end

  it "saves future defaults while keeping an existing release unchanged" do
    sign_in_browser
    release = Releases::Create.call
    connection = create_connection
    click_link "Réglages"
    select connection.label, from: "default_publishing"
    uncheck "Premier passage IA automatique"
    click_button "Enregistrer les choix par défaut"

    expect(page).to have_content("Les livres existants restent inchangés")
    expect(page).to have_unchecked_field("Premier passage IA automatique")
    expect(release.reload).to be_automatic_ai
    expect(release.provider_assignments.pluck(:provider_connection_id)).to all(be_nil)
  end

  it "assigns an unconfigured role deliberately without revealing credentials" do
    sign_in_browser
    release = Releases::Create.call(title: "Synthetic browser book")
    connection = create_connection
    visit release_connections_path(release)
    within("form#publishing_assignment") do
      select connection.label, from: "Connexion à affecter"
      click_button "Affecter à ce livre"
    end

    expect(page).to have_content("Connexion affectée explicitement")
    expect(page).to have_content(connection.identity_key)
    expect(page.html).not_to include("synthetic-private-credential")
  end

  it "creates a masked connection from its provider-specific form" do
    sign_in_browser
    click_link "Réglages"
    within("section[aria-labelledby='role-publishing']") do
      find("summary", text: "Ajouter une connexion C411").click
      fill_in "Libellé", with: "Browser C411"
      fill_in "Identité stable du compte ou projet", with: "browser-account"
      fill_in "Clé API", with: "browser-private-credential"
      click_button "Enregistrer la connexion"
    end

    expect(page).to have_content("Browser C411")
    expect(page).to have_content("•••••••• (configuré)")
    expect(page.html).not_to include("browser-private-credential")
  end
end
