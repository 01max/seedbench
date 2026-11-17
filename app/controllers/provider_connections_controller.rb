class ProviderConnectionsController < ApplicationController
  rescue_from Settings::ConnectionConfig::Invalid, Settings::RotateCredentials::Conflict, with: :redirect_with_error

  def create
    attributes = connection_params
    @requested_role = attributes[:role]
    connection = Settings::CreateConnection.call(**attributes)
    Drafts::Connect.call(connection: connection)
    redirect_to settings_provider_path(connection.role), notice: t('settings.connection_created'), status: :see_other
  end

  def rotate
    values = rotation_params
    connection = Settings::RotateCredentials.call(connection_id: params[:id], expected_version: Integer(values[:expected_version].to_s, exception: false),
      confirm_identity: values[:confirm_identity] == '1', credentials: values.fetch(:credentials, {}).to_h)
    redirect_to settings_provider_path(connection.role), notice: t('settings.secret_rotated'), status: :see_other
  end

  def check
    connection = Settings::TestConnection.call(connection_id: params.expect(:id))
    redirect_to settings_provider_path(connection.role, anchor: helpers.dom_id(connection)), status: :see_other
  end

  def import_drafts
    connection = ProviderConnection.find(params.expect(:id))
    return head :not_found unless connection.provider == 'c411' && !connection.configuration_incomplete?

    location = settings_provider_path(connection.role, anchor: helpers.dom_id(connection))
    Drafts::Import.call(connection: connection)
    redirect_to location, notice: t('settings.connection.drafts_imported'), status: :see_other
  rescue Providers::Failure, Drafts::Failure => error
    redirect_to location, alert: t('drafts.sync_failed', connection: connection.label, message: error.message), status: :see_other
  end

  def preview
    attributes = params[:id] ? preview_existing : connection_params
    result = Settings::TestConnection.preview(**attributes)
    render json: result.to_h
  rescue Settings::ConnectionConfig::Invalid => error
    render json: { status: 'failed', message: error.message }, status: :unprocessable_content
  end

  def discover_deluge
    values = params.expect(connection: [ :endpoint, credentials: [ :password ] ])
    access = Settings::ConnectionConfig.deluge_web(endpoint: values[:endpoint], credentials: values.fetch(:credentials, {}).to_h)
    render json: { daemons: Providers::Deluge.discover(**access) }
  rescue Settings::ConnectionConfig::Invalid, Providers::Failure => error
    render json: { message: error.message }, status: :unprocessable_content
  end

  def configure
    values = configuration_params
    connection = Settings::ConfigureConnection.call(connection_id: params[:id], expected_version: Integer(values[:expected_version].to_s, exception: false), options: values.fetch(:options, {}).to_h)
    redirect_to settings_provider_path(connection.role), notice: t('settings.options_updated'), status: :see_other
  end

  def complete
    values = completion_params
    connection = Settings::CompleteConnection.call(connection_id: params[:id], expected_version: Integer(values[:expected_version].to_s, exception: false),
      confirm_identity: values[:confirm_identity] == '1', endpoint: values[:endpoint], credentials: values.fetch(:credentials, {}), options: values.fetch(:options, {}))
    Drafts::Connect.call(connection: connection)
    redirect_to settings_provider_path(connection.role), notice: t('settings.connection_completed'), status: :see_other
  end

  private

  def preview_existing
    connection = ProviderConnection.find(params.expect(:id))
    attributes = connection.attributes.symbolize_keys.slice(:role, :label, :identity_key, :endpoint, :credentials, :options)
    attributes.merge(preview_edits(connection))
  end

  def preview_edits(connection)
    case params.expect(:kind)
    when 'rotation'
      { credentials: rotation_params.fetch(:credentials, {}).to_h }
    when 'configuration'
      { options: configuration_params.fetch(:options, {}).to_h }
    when 'completion'
      values = completion_params
      { endpoint: connection.endpoint || values[:endpoint], credentials: values.fetch(:credentials, {}), options: values.fetch(:options, {}) }
    else
      raise ActionController::ParameterMissing, :kind
    end
  end

  def redirect_with_error(error)
    role = @requested_role || ProviderConnection.find_by(id: params[:id])&.role
    definition = Providers::Catalog::ROLES[role]
    provider = definition&.provider if @requested_role
    location = definition ? settings_provider_path(role, provider: provider) : settings_path
    redirect_to location, alert: error.message, status: :see_other
  end

  def connection_params
    values = params.expect(connection: [ :role, :label, :identity_key, :endpoint, credentials: %i[api_key password], options: [ :model ] ]).to_h.symbolize_keys
    values[:credentials] = values.fetch(:credentials, {})
    values[:options] = values.fetch(:options, {})
    values
  end

  def rotation_params
    params.expect(rotation: [ :expected_version, :confirm_identity, credentials: %i[api_key password] ])
  end

  def configuration_params
    params.expect(configuration: [ :expected_version, options: [ :model ] ])
  end

  def completion_params
    params.expect(completion: [ :expected_version, :confirm_identity, :endpoint, credentials: %i[api_key password], options: [ :model ] ]).to_h.symbolize_keys
  end
end
