class SessionsController < Devise::SessionsController
  prepend_before_action :protect_browser_session, :verify_authenticity_token
end
