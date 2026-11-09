class ReleaseActionsController < ApplicationController
  def create
    attributes = params.expect(edit: [ :expected_revision, *Releases::Save::LIMITS.keys ])
    Releases::ReviewAction.call(release_id: params.expect(:id), kind: params.expect(:kind),
      expected_revision: Integer(attributes.delete(:expected_revision), exception: false), changes: attributes.to_h)
  rescue Releases::ReviewAction::UnknownAction => error
    render json: { message: error.message }, status: :bad_request
  rescue Releases::ReviewAction::Unavailable => error
    render json: { message: error.message, revision: error.revision }, status: :service_unavailable
  rescue Releases::Save::InvalidChanges => error
    render json: { message: error.message }, status: :unprocessable_content
  rescue Releases::RevisionConflict
    render_conflict
  end

  private

  def render_conflict
    release = Release.find(params.expect(:id))
    render json: { message: t("workbench.errors.action_conflict"),
      current_revision: release.input_revision, values: Releases::EditorValues.call(release: release) }, status: :conflict
  end
end
