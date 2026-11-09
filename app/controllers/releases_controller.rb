class ReleasesController < ApplicationController
  before_action :load_workspace, only: %i[index show]

  def index
    render :show
  end

  def show
  end

  def update
    release = persist_edits
    respond_to do |format|
      format.json { render json: { revision: release.input_revision } }
      format.html { redirect_to release_path(release), status: :see_other, notice: t('releases.saved') }
    end
  rescue Releases::RevisionConflict
    render_save_error(t('workbench.errors.save_conflict'), :conflict)
  rescue Releases::Save::InvalidChanges => error
    render_save_error(error.message, :unprocessable_content)
  end

  private

  def persist_edits
    attributes = params.expect(edit: [ :expected_revision, *Releases::Save::LIMITS.keys ])
    Releases::Save.call(release_id: params.expect(:id), expected_revision: Integer(attributes.delete(:expected_revision), exception: false), changes: attributes.to_h)
  end

  def load_workspace
    @queue = Releases::Queue.call(**params.permit(:q, :state, :page).to_h.symbolize_keys, release_id: params[:id])
    @release = @queue.selected
    load_selection if @release
  end

  def load_selection
    @snapshot = Releases::Snapshot.call(release: @release)
    @checklist = Releases::Checklist.call(release: @release, snapshot: @snapshot)
    @content_workspace = Content::Workspace.call(release: @release)
    @editor_values = Releases::EditorValues.call(release: @release)
    @workflow_active = @release.workflow_operations.exists?(state: %w[pending running])
  end

  def render_save_error(message, status)
    current = Release.find(params.expect(:id))
    render json: { message: message, current_revision: current.input_revision, values: Releases::EditorValues.call(release: current) }, status: status
  end
end
