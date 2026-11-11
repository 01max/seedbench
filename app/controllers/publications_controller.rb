class PublicationsController < ApplicationController
  def create
    Publications::Reconcile.call(release_id: params.expect(:release_id))
    @publication_notice = t('publication.confirmed')
    render_status
  rescue Publications::Failure, Providers::Failure => error
    @publication_error = error.message
    render_status(:unprocessable_content)
  end

  private

  def render_status(status = :ok)
    state = Releases::Status.call(release_id: params.expect(:release_id))
    @release, @snapshot, @checklist, @workflow_active = state.release, state.snapshot, state.checklist, state.active
    render partial: 'releases/status', status: status
  end
end
