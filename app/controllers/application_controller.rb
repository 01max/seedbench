class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true
  before_action :protect_browser_session
  before_action :authenticate_operator!, unless: :devise_controller?
  before_action :require_editable_release, if: -> { request.path_parameters[:editable_release] }
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def require_editable_release
    release_id = request.path_parameters.values_at(:release_id, :id).compact.first
    return unless ReleaseEvent.exists?(release_id: release_id, name: Release::C411_IMPORT_EVENT)

    message = t('workbench.c411.read_only')
    if request.format.json?
      render json: { message: message }, status: :forbidden
    else
      render plain: message, status: :forbidden
    end
  end

  def protect_browser_session
    request.session_options[:secure] = request.ssl?
    response.headers['Cache-Control'] = 'no-store, private'
  end

  def after_sign_out_path_for(_scope)
    new_operator_session_path
  end
end
