class DuplicateReviewsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(duplicate: %i[expected_revision kind check_id candidate_key decision reason])
    perform(attributes)
    @duplicate_notice = t(attributes[:kind] == 'review' || attributes[:kind] == 'manual' ? 'duplicates.reviewed' : 'duplicates.queued')
    render_panel
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Duplicates::Failure => error
    render_error(error, :unprocessable_content)
  end

  private

  def perform(attributes)
    arguments = { release_id: @release.id, expected_revision: Integer(attributes[:expected_revision], exception: false) }
    case attributes[:kind]
    when 'review'
      Duplicates::Review.call(**arguments, **attributes.slice(:check_id, :candidate_key, :decision, :reason).to_h.symbolize_keys)
    when 'manual'
      Duplicates::Review.manual_exception(**arguments, check_id: attributes[:check_id], reason: attributes[:reason])
    else
      Duplicates::Request.call(**arguments)
    end
  end

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
