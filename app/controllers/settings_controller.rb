class SettingsController < ApplicationController
  rescue_from Settings::SetDefaults::Invalid, Settings::SetDefaults::Conflict do |error|
    redirect_to settings_path, alert: error.message, status: :see_other
  end

  def show
    @connections = Settings::Overview.call
    @defaults = Settings::DefaultsSnapshot.call
  end

  def update
    values = params.expect(defaults: [ :automatic_ai, :expected_revision, connection_ids: %i[publishing torrent_client ai image_host] ])
    Settings::SetDefaults.call(automatic_ai: values[:automatic_ai] == "1", connection_ids: values.fetch(:connection_ids, {}).to_h,
      expected_revision: Integer(values[:expected_revision].to_s, exception: false))
    redirect_to settings_path, notice: t("settings.defaults_updated"), status: :see_other
  end
end
