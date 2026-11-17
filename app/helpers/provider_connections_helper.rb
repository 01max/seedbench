module ProviderConnectionsHelper
  def provider_field_labels(definition, endpoint:, model:)
    labels = {}
    labels[:endpoint] = t('settings.connection.deluge_endpoint') if endpoint
    labels[definition.secret.to_sym] = t("settings.connection.#{definition.secret}")
    labels[:model] = t('settings.connection.model_id') if model
    labels
  end

  def connection_test_data(path)
    { controller: 'connection-test', action: 'input->connection-test#clear', connection_test_url_value: path,
      connection_test_pending_value: t('settings.connection.test_pending'), connection_test_failed_value: t('settings.connection.test_unavailable') }
  end
end
