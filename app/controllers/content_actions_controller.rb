class ContentActionsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    attributes = params.expect(content: [ :kind, :expected_revision, :proposal_id ])
    @release = Release.find(params.expect(:release_id))
    result = Content::Action.call(release_id: @release.id, kind: attributes[:kind], proposal_id: attributes[:proposal_id],
      expected_revision: Integer(attributes[:expected_revision], exception: false))
    @selected_proposal_id = result.id if result.is_a?(ContentProposal)
    @content_notice = t('content.actions.completed')
    render_panel
  rescue Releases::RevisionConflict, Content::Accept::StaleProposal => error
    render_error(error, :conflict)
  rescue Content::Propose::InvalidKind, Content::CoverPatch::Unavailable, Content::Confirm::InvalidContent, Releases::Save::InvalidChanges => error
    render_error(error, :unprocessable_content)
  end

  private

  def render_panel(status: :ok)
    @release.reload
    @content_workspace = Content::Workspace.call(release: @release)
    render partial: 'releases/content_frame', status: status
  end

  def render_error(error, status)
    @content_error = error.message
    render_panel(status: status)
  end
end
