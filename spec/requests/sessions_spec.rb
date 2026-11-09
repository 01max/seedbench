require 'rails_helper'

RSpec.describe 'Operator sessions' do
  include ActiveSupport::Testing::TimeHelpers

  it 'protects private pages and leaves health checks available' do
    get root_path
    expect(response).to redirect_to(new_operator_session_path)
    get appearance_path
    expect(response).to redirect_to(new_operator_session_path)
    get rails_health_check_path
    expect(response).to have_http_status(:ok)
  end

  it 'logs in with a private cookie and revokes it on logout', :aggregate_failures do
    sign_in_operator
    expect(response).to redirect_to(root_path)
    expect(Array(response.headers['Set-Cookie']).join).to include('httponly', 'samesite=lax')
    record = ActiveRecord::SessionStore::Session.order(:id).last
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to include('no-store')
    delete destroy_operator_session_path
    expect(ActiveRecord::SessionStore::Session.exists?(record.id)).to be(false)
    get root_path
    expect(response).to redirect_to(new_operator_session_path)
  end

  it "locks the account across clients until Devise's unlock interval expires" do
    create_operator
    10.times { post operator_session_path, params: { operator: { password: 'incorrect' } } }
    expect(Operator.sole.access_locked?).to be(true)
    cookies.delete('_seedbench_session')
    post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }, headers: { 'REMOTE_ADDR' => '192.0.2.2' }
    expect(response).to have_http_status(:unprocessable_content)
    travel 16.minutes do
      post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }
    end

    expect(response).to redirect_to(root_path)
    expect(Operator.sole.failed_attempts).to eq(0)
    expect(Operator.sole.locked_at).to be_nil
  end

  it 'clears failed attempts after a successful login' do
    create_operator
    2.times { post operator_session_path, params: { operator: { password: 'incorrect' } } }
    post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }

    expect(response).to redirect_to(root_path)
    expect(Operator.sole.failed_attempts).to eq(0)
  end

  %w[X-Forwarded-For Client-Ip Forwarded].each do |header|
    it "keeps the account locked when #{header} values change" do
      create_operator
      statuses = Array.new(11) do |index|
        address = "198.51.100.#{index + 1}"
        value = header == 'Forwarded' ? "for=#{address}" : address
        post operator_session_path, params: { operator: { password: 'incorrect' } }, headers: { 'REMOTE_ADDR' => '192.168.1.77', header => value }
        response.status
      end

      expect(statuses).to eq(Array.new(11, 422))
      expect(Operator.sole.access_locked?).to be(true)
    end
  end

  it 'rejects invalid CSRF on login and authenticated logout' do
    sign_in_operator
    ids = ActiveRecord::SessionStore::Session.ids
    begin
      ActionController::Base.allow_forgery_protection = true
      delete destroy_operator_session_path, params: { authenticity_token: 'forged' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(ActiveRecord::SessionStore::Session.ids).to eq(ids)
      post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD }, authenticity_token: 'forged' }
      expect(response).to have_http_status(:unprocessable_content)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  it 'rejects a copied session cookie after logout' do
    sign_in_operator
    copied_cookie = cookies['_seedbench_session']
    delete destroy_operator_session_path
    cookies['_seedbench_session'] = copied_cookie
    get settings_path

    expect(response).to redirect_to(new_operator_session_path)
  end

  it 'rotates the anonymous session identifier after Devise authenticates' do
    create_operator
    get new_operator_session_path
    anonymous_cookie = cookies['_seedbench_session']
    post operator_session_path, params: { operator: { password: OperatorHelpers::PASSWORD } }

    expect(cookies['_seedbench_session']).not_to eq(anonymous_cookie)
    expect(response).to redirect_to(root_path)
  end

  it 'rejects an incorrect password and an uninitialized account consistently' do
    post operator_session_path, params: { operator: { password: 'incorrect' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Mot de passe incorrect ou compte non initialisé')
    create_operator
    post operator_session_path, params: { operator: { password: 'incorrect' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Mot de passe incorrect ou compte non initialisé')
  end

  it 'does not expose registration or browser password recovery' do
    get '/operators/sign_up'
    expect(response).to have_http_status(:not_found)
    get '/operators/password/new'
    expect(response).to have_http_status(:not_found)
  end
end
