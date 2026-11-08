require "rails_helper"

RSpec.describe "Completing provider connections" do
  def completion
    { expected_version: 0, confirm_identity: "1", credentials: { api_key: "completed-private-credential" }, options: { model: "synthetic-model" } }
  end

  it "completes a legacy connection through its protected form with masked results" do
    sign_in_operator
    connection = ProviderConnection.create!(role: "ai", provider: "openai", identity_key: "legacy-account", label: "Legacy AI")
    patch complete_provider_connection_path(connection), params: { completion: completion }
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Configuration complétée", "••••••••", "synthetic-model")
    expect(response.body).not_to include("completed-private-credential", "Compléter la configuration")
    expect(connection.reload).not_to be_configuration_incomplete
  end

  it "rejects a stale completion without replacing the stored secret" do
    sign_in_operator
    connection = ProviderConnection.create!(role: "ai", provider: "openai", identity_key: "legacy-account", label: "Legacy AI")
    patch complete_provider_connection_path(connection), params: { completion: completion.merge(expected_version: 1) }
    follow_redirect!

    expect(response.body).to include("La connexion a changé")
    expect(connection.reload.credentials).to be_nil
  end

  it "requires authentication for completion" do
    patch complete_provider_connection_path(123), params: { completion: completion }

    expect(response).to redirect_to(new_session_path)
  end

  it "requires valid CSRF before completing a connection" do
    sign_in_operator
    begin
      ActionController::Base.allow_forgery_protection = true
      patch complete_provider_connection_path(123), params: { authenticity_token: "forged", completion: completion }

      expect(response).to have_http_status(:unprocessable_content)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
