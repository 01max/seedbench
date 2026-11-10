class DuplicateReviewsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(duplicate: [ :expected_revision ])
    Duplicates::Request.call(release_id: @release.id, expected_revision: Integer(attributes[:expected_revision], exception: false))
    @duplicate_notice = t('duplicates.queued')
    render_panel
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Duplicates::Failure => error
    render_error(error, :unprocessable_content)
  end

  private

  def render_panel(status: :ok)
    @release.reload
    @duplicate_workspace = Duplicates::Workspace.call(release: @release)
    render partial: 'releases/duplicates_frame', status: status
  end

  def render_error(error, status)
    @duplicate_error = error.message
    render_panel(status: status)
  end
end
