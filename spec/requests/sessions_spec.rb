require "rails_helper"

RSpec.describe "Operator sessions" do
  it "protects private pages and leaves health checks available" do
    get root_path
    expect(response).to redirect_to(new_operator_session_path)
    get appearance_path
    expect(response).to redirect_to(new_operator_session_path)
    get rails_health_check_path
    expect(response).to have_http_status(:ok)
  end

  it "logs in with a private cookie and revokes it on logout", :aggregate_failures do
    sign_in_operator
    expect(response).to redirect_to(root_path)
    expect(Array(response.headers["Set-Cookie"]).join).to include("httponly", "samesite=lax")
    record = BrowserSession.order(:id).last
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    delete destroy_operator_session_path
    expect(BrowserSession.exists?(record.id)).to be(false)
    get root_path
    expect(response).to redirect_to(new_operator_session_path)
  end

  it "renders a generic rejection and rate-limit response" do
    create_operator
    post operator_session_path, params: { operator: { password: "incorrect" } }
    expect(response).to have_http_status(:unprocessable_content)
    9.times { Authentication::Throttle.check!(ip: "127.0.0.1") }
    post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }
    expect(response).to have_http_status(:too_many_requests)
  end

  %w[X-Forwarded-For Client-Ip Forwarded].each do |header|
    it "keeps forged #{header} values in the same login throttle bucket" do
      create_operator
      statuses = Array.new(11) do |index|
        address = "198.51.100.#{index + 1}"
        value = header == "Forwarded" ? "for=#{address}" : address
        post operator_session_path, params: { operator: { password: "incorrect" } }, headers: { "REMOTE_ADDR" => "192.168.1.77", header => value }
        response.status
      end

      expect(statuses).to eq([ *Array.new(10, 422), 429 ])
      expect(LoginThrottle.sole.attempts).to eq(10)
    end
  end

  it "rejects invalid CSRF on login and authenticated logout" do
    sign_in_operator
    ids = BrowserSession.ids
    begin
      ActionController::Base.allow_forgery_protection = true
      delete destroy_operator_session_path, params: { authenticity_token: "forged" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(BrowserSession.ids).to eq(ids)
      post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD }, authenticity_token: "forged" }
      expect(response).to have_http_status(:unprocessable_content)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  it "rejects a copied session cookie after logout" do
    sign_in_operator
    copied_cookie = cookies["_seedbench_session"]
    delete destroy_operator_session_path
    cookies["_seedbench_session"] = copied_cookie
    get settings_path

    expect(response).to redirect_to(new_operator_session_path)
  end

  it "rotates the anonymous session identifier after Devise authenticates" do
    create_operator
    get new_operator_session_path
    anonymous_cookie = cookies["_seedbench_session"]
    post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }

    expect(cookies["_seedbench_session"]).not_to eq(anonymous_cookie)
    expect(response).to redirect_to(root_path)
  end

  it "rejects an incorrect password and an uninitialized account consistently" do
    post operator_session_path, params: { operator: { password: "incorrect" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Mot de passe incorrect ou compte non initialisé")
    create_operator
    post operator_session_path, params: { operator: { password: "incorrect" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Mot de passe incorrect ou compte non initialisé")
  end

  it "does not expose registration or browser password recovery" do
    get "/operators/sign_up"
    expect(response).to have_http_status(:not_found)
    get "/operators/password/new"
    expect(response).to have_http_status(:not_found)
  end
end
