class AiActionsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    render_panel
  end

  def create
    @release = Release.find(params.expect(:release_id))
    attributes = params.expect(assistance: [ :expected_revision, :purpose, :kind, :run_id, :candidate_index, :field, { scope: [ :mode, :note, { evidence_ids: [] } ] } ])
    perform(attributes)
    @ai_notice = t(attributes[:kind].presence == 'accept_prose' || attributes[:kind] == 'adopt_fact' ? 'ai.accepted' : 'ai.queued')
    render_panel
  rescue Releases::RevisionConflict => error
    render_error(error, :conflict)
  rescue Ai::Failure, Ebooks::ReviewFact::InvalidCandidate, Releases::Save::InvalidChanges => error
    render_error(error, :unprocessable_content)
  end

  private

  def perform(attributes)
    arguments = { release_id: @release.id, expected_revision: Integer(attributes[:expected_revision], exception: false) }
    case attributes[:kind]
    when 'accept_prose'
      Ai::AcceptProse.call(**arguments, run_id: attributes[:run_id], field: attributes[:field])
    when 'adopt_fact'
      Ai::AcceptFact.call(**arguments, run_id: attributes[:run_id], candidate_index: Integer(attributes[:candidate_index], exception: false))
    when nil, '', 'run'
      Ai::Request.call(**arguments, purpose: attributes[:purpose], scope: attributes.to_h.fetch('scope', {}))
    else
      raise Ai::Failure.new(:invalid_action)
    end
  end

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
