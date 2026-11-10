class AiActionsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(assistance: [ :expected_revision, :purpose, { scope: [ :mode, :note, { evidence_ids: [] } ] } ])
    Ai::Request.call(release_id: @release.id, expected_revision: Integer(attributes[:expected_revision], exception: false),
      purpose: attributes[:purpose], scope: attributes.to_h.fetch('scope', {}))
    @ai_notice = t('ai.queued')
    render_panel
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Ai::Failure => error
    render_error(error, :unprocessable_content)
  end

  private

  def render_panel(status: :ok)
    @release.reload
    @ai_workspace = Ai::Workspace.call(release: @release)
    render partial: 'releases/ai_frame', status: status
  end

  def render_error(error, status)
    @ai_error = error.message
    render_panel(status: status)
  end
end
