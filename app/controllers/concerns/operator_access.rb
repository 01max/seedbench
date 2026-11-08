module OperatorAccess
  extend ActiveSupport::Concern

  included do
    before_action :require_operator
    before_action :prevent_private_caching
    helper_method :current_operator
  end

  private

  def current_operator
    @current_operator ||= Authentication::Resume.call(token: cookies.encrypted[:operator_session])
  end

  def require_operator
    redirect_to new_session_path unless current_operator
  end

  def prevent_private_caching
    response.headers["Cache-Control"] = "no-store, private"
  end
end
