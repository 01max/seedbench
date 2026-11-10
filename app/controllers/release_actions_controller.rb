class ReleaseActionsController < ApplicationController
  def create
    attributes = action_attributes
    result = Releases::ReviewAction.call(release_id: params.expect(:id), kind: params.expect(:kind),
      expected_revision: Integer(attributes.delete(:expected_revision), exception: false), changes: attributes.to_h)
    render_action(result)
  rescue Releases::ReviewAction::UnknownAction => error
    render json: { message: error.message }, status: :bad_request
  rescue Releases::ReviewAction::Unavailable => error
    render json: { message: error.message, revision: error.revision }, status: :service_unavailable
  rescue Drafts::Failure, Releases::Save::InvalidChanges, Preparation::Failure, Providers::C411::EbookNaming::InvalidName => error
    render json: { message: error.message }, status: :unprocessable_content
  rescue Releases::RevisionConflict
    render_conflict
  end

  private

  def action_attributes
    params.expect(edit: [ :expected_revision, *Releases::Save::LIMITS.keys ])
  end

  def render_action(result)
    release = Release.find(params.expect(:id))
    render json: { revision: release.input_revision, values: Releases::EditorValues.call(release: release),
      operation_id: result.is_a?(WorkflowOperation) ? result.id : nil,
      message: action_message }
  end

  def action_message
    return t('drafts.queued') if params[:kind] == 'draft'
    t("preparation.#{params[:kind] == 'prepare' ? 'queued' : 'suggested'}")
  end

  def render_conflict
    release = Release.find(params.expect(:id))
    render json: { message: t('workbench.errors.action_conflict'),
      current_revision: release.input_revision, values: Releases::EditorValues.call(release: release) }, status: :conflict
  end
end
