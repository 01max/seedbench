class SessionsController < Devise::SessionsController
  prepend_before_action :protect_browser_session, :verify_authenticity_token

  rescue_from Authentication::Throttle::RateLimited do |error|
    @error = error.message
    render :new, status: :too_many_requests
  end

  def create
    Authentication::Throttle.check!(ip: request.get_header("REMOTE_ADDR"))
    super
  end
end
