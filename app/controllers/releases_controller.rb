class ReleasesController < ApplicationController
  before_action :load_workspace, only: %i[index show]

  def index
    render :show
  end

  def show
  end

  private

  def load_workspace
    @queue = Releases::Queue.call(**params.permit(:q, :state, :page).to_h.symbolize_keys, release_id: params[:id])
    @release = @queue.selected
    @snapshot = Releases::Snapshot.call(release: @release) if @release
  end
end
