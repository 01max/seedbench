class ProviderConnectionsController < ApplicationController
  rescue_from Settings::ConnectionConfig::Invalid, Settings::RotateCredentials::Conflict do |error|
    redirect_to settings_path, alert: error.message, status: :see_other
  end

  def create
    connection = Settings::CreateConnection.call(**connection_params)
    Drafts::Connect.call(connection: connection)
    redirect_to settings_path, notice: t('settings.connection_created'), status: :see_other
  end

  def rotate
    values = params.expect(rotation: [ :expected_version, :confirm_identity, credentials: %i[api_key password] ])
    Settings::RotateCredentials.call(connection_id: params[:id], expected_version: Integer(values[:expected_version].to_s, exception: false),
      confirm_identity: values[:confirm_identity] == '1', credentials: values.fetch(:credentials, {}).to_h)
    redirect_to settings_path, notice: t('settings.secret_rotated'), status: :see_other
  end

  def check
    Settings::TestConnection.call(connection_id: params[:id])
    redirect_to settings_path, status: :see_other
  end

  def configure
    values = params.expect(configuration: [ :expected_version, options: [ :model ] ])
    Settings::ConfigureConnection.call(connection_id: params[:id], expected_version: Integer(values[:expected_version].to_s, exception: false), options: values.fetch(:options, {}).to_h)
    redirect_to settings_path, notice: t('settings.options_updated'), status: :see_other
  end

  def complete
    values = params.expect(completion: [ :expected_version, :confirm_identity, :endpoint, credentials: %i[api_key password], options: [ :model ] ]).to_h.symbolize_keys
    connection = Settings::CompleteConnection.call(connection_id: params[:id], expected_version: Integer(values[:expected_version].to_s, exception: false),
      confirm_identity: values[:confirm_identity] == '1', endpoint: values[:endpoint], credentials: values.fetch(:credentials, {}), options: values.fetch(:options, {}))
    Drafts::Connect.call(connection: connection)
    redirect_to settings_path, notice: t('settings.connection_completed'), status: :see_other
  end

  private

  def connection_params
    values = params.expect(connection: [ :role, :label, :identity_key, :endpoint, credentials: %i[api_key password], options: [ :model ] ]).to_h.symbolize_keys
    values[:credentials] = values.fetch(:credentials, {})
    values[:options] = values.fetch(:options, {})
    values
  end
end
