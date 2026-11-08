require "rails_helper"

RSpec.describe "Private access boundary" do
  include ActiveSupport::Testing::TimeHelpers

  it "blocks release/settings reads and all configuration writes without a session" do
    release = Releases::Create.call(title: "Private book title")
    connection = create_connection
    [ root_path, settings_path, release_connections_path(release) ].each do |path|
      get path
      expect(response).to redirect_to(new_operator_session_path)
      expect(response.body).not_to include("Private book title", "synthetic-private-credential")
    end
    post provider_connections_path, params: { connection: connection_attributes(identity: "forged") }
    expect(response).to redirect_to(new_operator_session_path)
    post check_provider_connection_path(connection)
    expect(response).to redirect_to(new_operator_session_path)
    expect(ProviderConnection.count).to eq(1)
  end

  it "blocks unauthenticated default and assignment changes" do
    release = Releases::Create.call
    connection = create_connection
    patch settings_path, params: { defaults: { automatic_ai: "0" } }
    expect(response).to redirect_to(new_operator_session_path)
    patch release_connections_path(release), params: { assignment: { role: "publishing", connection_id: connection.id, expected_revision: 0 } }
    expect(response).to redirect_to(new_operator_session_path)
    patch rotate_provider_connection_path(connection), params: { rotation: { credentials: { api_key: "forged" } } }
    expect(response).to redirect_to(new_operator_session_path)
    expect(release.provider_assignments.pluck(:provider_connection_id)).to all(be_nil)
    expect(Settings::DefaultsSnapshot.call.automatic_ai).to be(true)
  end

  it "rejects a replayed cookie after twelve hours without activity" do
    sign_in_operator
    copied_cookie = cookies["_seedbench_session"]

    travel 13.hours do
      cookies["_seedbench_session"] = copied_cookie
      get settings_path
      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response).to redirect_to(new_operator_session_path)
      follow_redirect!
      expect(response.body).to include("Votre session a expiré")
    end
  end

  it "keeps an active session open beyond twelve hours" do
    sign_in_operator
    started_at = Time.current

    [ 11.hours, 22.hours ].each do |elapsed|
      travel_to(started_at + elapsed) do
        get settings_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  it "rejects a tampered authentication cookie" do
    sign_in_operator
    cookies["_seedbench_session"] = "forged-cookie"
    get settings_path
    expect(response).to redirect_to(new_operator_session_path)
  end

  it "requires fresh authentication after password recovery" do
    sign_in_operator
    Authentication::ResetPassword.call(password: "New protected password", password_confirmation: "New protected password")
    get settings_path

    expect(response).to redirect_to(new_operator_session_path)
  end

  it "uses Secure cookies for HTTPS login" do
    create_operator
    https!
    post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }

    expect(Array(response.headers["Set-Cookie"]).join).to include("secure", "httponly", "samesite=lax")
  end

  it "keeps Secure cookies on Devise's early redirect for an authenticated HTTPS session" do
    sign_in_operator
    https!
    get new_operator_session_path

    expect(response).to redirect_to(root_path)
    expect(Array(response.headers["Set-Cookie"]).join).to include("secure", "httponly", "samesite=lax")
  end

  it "rejects authenticated settings changes with invalid CSRF" do
    sign_in_operator
    begin
      ActionController::Base.allow_forgery_protection = true
      post provider_connections_path, params: { authenticity_token: "forged", connection: connection_attributes }
      expect(response).to have_http_status(:unprocessable_content)
      expect(ProviderConnection.count).to eq(0)
      patch settings_path, params: { authenticity_token: "forged", defaults: { automatic_ai: "0" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(Settings::DefaultsSnapshot.call.automatic_ai).to be(true)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
