class ReleaseChecksController < ApplicationController
  before_action :load_release

  def create
    change_mark
    render_status
  rescue Releases::RevisionConflict => error
    @check_error = "Le livre a changé (révision #{error.actual_revision}). Relisez les contrôles."
    render_status(status: :conflict)
  rescue Releases::MarkCheck::NotManual, Releases::AcknowledgeFinding::NotUncertain, Releases::AcknowledgeFinding::StaleFinding => error
    @check_error = error.message
    render_status(status: :unprocessable_content)
  end

  private

  def load_release
    @release = Release.find(params.expect(:release_id))
  end

  def change_mark
    attributes = params.expect(mark: %i[key checked expected_revision finding_id number])
    common = { release_id: @release.id, expected_revision: Integer(attributes.fetch(:expected_revision), exception: false) }
    checked = attributes[:checked] == "1"
    if attributes[:finding_id].present?
      Releases::AcknowledgeFinding.call(**common, finding_id: attributes[:finding_id], number: Integer(attributes[:number], exception: false), acknowledged: checked)
    else
      Releases::MarkCheck.call(**common, key: attributes[:key], checked: checked)
    end
  end

  def render_status(status: :ok)
    state = Releases::Status.call(release_id: @release.id)
    @release, @snapshot, @checklist, @workflow_active = state.release, state.snapshot, state.checklist, state.active
    render partial: "releases/status", status: status
  end
end
