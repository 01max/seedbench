class ReleaseStatusesController < ApplicationController
  def show
    state = Releases::Status.call(release_id: params.expect(:release_id))
    @release, @snapshot, @checklist, @workflow_active = state.release, state.snapshot, state.checklist, state.active
    render partial: "releases/status"
  end
end
