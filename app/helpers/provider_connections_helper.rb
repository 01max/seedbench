module ProviderConnectionsHelper
  def provider_field_labels(definition, endpoint:, model:)
    labels = {}
    labels[:endpoint] = t('settings.connection.deluge_endpoint') if endpoint
    labels[definition.secret.to_sym] = t("settings.connection.#{definition.secret}")
    labels[:model] = t('settings.connection.model_id') if model
    labels
  end

  def connection_test_data(path, discover_deluge: false)
    data = { controller: 'connection-test', action: 'input->connection-test#clear', connection_test_url_value: path,
      connection_test_pending_value: t('settings.connection.test_pending'), connection_test_failed_value: t('settings.connection.test_unavailable') }
    return data unless discover_deluge

    data.merge(controller: 'connection-test deluge-daemons', action: 'input->connection-test#clear input->deluge-daemons#reset',
      deluge_daemons_url_value: discover_deluge_provider_connections_path, deluge_daemons_messages_value: t('settings.connection.deluge_discovery.messages').to_json)
  end
end
