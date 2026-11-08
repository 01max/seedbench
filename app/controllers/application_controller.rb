class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true
  before_action :protect_browser_session
  before_action :authenticate_operator!, unless: :devise_controller?
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def protect_browser_session
    request.session_options[:secure] = request.ssl?
    response.headers["Cache-Control"] = "no-store, private"
  end

  def after_sign_out_path_for(_scope)
    new_operator_session_path
  end
end
