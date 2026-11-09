class PreparationsController < ApplicationController
  def show
    @release = Release.find(params.expect(:release_id))
    Preparation::Observe.call(release: @release)
    @snapshot = Releases::Snapshot.call(release: @release)
    render partial: 'releases/files'
  end
end
