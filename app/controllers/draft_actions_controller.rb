class DraftActionsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(draft: [ :kind, :expected_revision, :payload_choice, :confirmed, :choice ])
    linked = link_payload(attributes)
    redirect_to release_path(linked), status: :see_other
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Drafts::Failure => error
    render_error(error, :unprocessable_content)
  end

  private

  def link_payload(attributes)
    raise Drafts::Failure.new(:invalid_action) unless attributes[:kind] == 'link'
    target, revision = attributes[:payload_choice].to_s.split(':', 2)
    Drafts::Link.call(release_id: @release.id, payload_release_id: target, payload_revision: Integer(revision, exception: false),
      expected_revision: Integer(attributes[:expected_revision], exception: false), confirmed: attributes[:confirmed] == '1', choice: attributes[:choice])
  end

  def render_panel(status: :ok)
    @release.reload
    @draft_workspace = Drafts::Workspace.call(release: @release)
    render partial: 'releases/draft_frame', status: status
  end

  def render_error(error, status)
    @draft_error = error.message
    render_panel(status: status)
  end
end
