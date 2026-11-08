require "rails_helper"

RSpec.describe "Operator sessions" do
  it "protects private pages and leaves health checks available" do
    get root_path
    expect(response).to redirect_to(new_session_path)
    get appearance_path
    expect(response).to redirect_to(new_session_path)
    get rails_health_check_path
    expect(response).to have_http_status(:ok)
  end

  it "logs in with a private cookie and revokes it on logout", :aggregate_failures do
    sign_in_operator
    expect(response).to redirect_to(root_path)
    expect(response.headers["Set-Cookie"].join).to include("httponly", "samesite=lax")
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    delete session_path
    expect(LoginSession.count).to eq(0)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "renders a generic rejection and rate-limit response" do
    create_operator
    post session_path, params: { password: "incorrect" }
    expect(response).to have_http_status(:unprocessable_content)
    9.times { Authentication::Throttle.check!(ip: "127.0.0.1") }
    post session_path, params: { password: OperatorHelpers::PASSWORD }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "rejects invalid CSRF on login and authenticated logout" do
    sign_in_operator
    begin
      ActionController::Base.allow_forgery_protection = true
      delete session_path, params: { authenticity_token: "forged" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(LoginSession.count).to eq(1)
      post session_path, params: { password: OperatorHelpers::PASSWORD, authenticity_token: "forged" }
      expect(response).to have_http_status(:unprocessable_content)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
