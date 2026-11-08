class SessionsController < ApplicationController
  skip_before_action :require_operator, only: %i[new create]

  def new
  end

  def create
    result = Authentication::SignIn.call(password: params[:password], ip: request.get_header("REMOTE_ADDR"))
    reset_session
    cookies.encrypted[:operator_session] = { value: result.token, expires: result.expires_at,
      httponly: true, same_site: :lax, secure: request.ssl? }
    redirect_to root_path, status: :see_other
  rescue Authentication::SignIn::InvalidCredentials
    @error = "Mot de passe incorrect ou compte non initialisé."
    render :new, status: :unprocessable_content
  rescue Authentication::Throttle::RateLimited => error
    @error = error.message
    render :new, status: :too_many_requests
  end

  def destroy
    Authentication::SignOut.call(token: cookies.encrypted[:operator_session])
    reset_session
    cookies.delete(:operator_session)
    redirect_to new_session_path, status: :see_other
  end
end
