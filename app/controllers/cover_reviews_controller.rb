class CoverReviewsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(cover: [ :kind, :source, :expected_revision, :image, :image_url, :isbn,
      { review: %i[edition_match quality_reviewed comparable_detail note] } ])
    Covers::Action.call(release_id: @release.id, expected_revision: Integer(attributes.delete(:expected_revision), exception: false), attributes: attributes.to_h)
    @cover_notice = t(attributes[:kind] == 'lookup' ? 'covers.lookup_queued' : 'covers.selected')
    render_panel
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Covers::Failure, Ebooks::Action::UnknownAction, Ebooks::EditionRecord::InvalidIsbn => error
    render_error(error, :unprocessable_content)
  end

  private

  def render_panel(status: :ok)
    @release.reload
    @cover_workspace = Covers::Workspace.call(release: @release)
    render partial: 'releases/covers_frame', status: status
  end

  def render_error(error, status)
    @cover_error = error.message
    render_panel(status: status)
  end
end
