class ReleaseConnectionsController < ApplicationController
  rescue_from Settings::SetDefaults::Invalid, Settings::AssignConnection::AlreadyAssigned, Releases::RevisionConflict do |error|
    redirect_to release_connections_path(params[:release_id]), alert: error.message, status: :see_other
  end

  def show
    @release = Release.find(params.expect(:release_id))
    @connections = Settings::Overview.call
  end

  def update
    values = params.expect(assignment: %i[role connection_id expected_revision])
    Settings::AssignConnection.call(release_id: params[:release_id], role: values[:role], connection_id: values[:connection_id],
      expected_revision: Integer(values[:expected_revision].to_s, exception: false))
    redirect_to release_connections_path(params[:release_id]), notice: t("settings.connection_assigned"), status: :see_other
  end
end
