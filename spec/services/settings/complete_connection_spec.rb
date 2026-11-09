require 'rails_helper'

RSpec.describe Settings::CompleteConnection do
  def legacy_connection(role = 'publishing', **attributes)
    definition = Providers::Catalog.fetch(role)
    ProviderConnection.create!(role: role, provider: definition.provider, identity_key: 'legacy-account', label: 'Legacy connection', **attributes)
  end

  def complete(connection, **changes)
    described_class.call(connection_id: connection.id, expected_version: 0, confirm_identity: true,
      **connection_attributes(connection.role).slice(:endpoint, :credentials, :options), **changes)
  end

  Providers::Catalog::ROLES.each_key do |role|
    it "completes a legacy #{role} connection in one save" do
      connection = legacy_connection(role)
      complete(connection)

      expect(connection.reload).not_to be_configuration_incomplete
      expect(connection.endpoint).to eq(connection_attributes(role).fetch(:endpoint))
      expect(connection.credentials).to eq(connection_attributes(role).fetch(:credentials))
      expect(connection.credentials_version).to eq(1)
      expect(connection.check_status).to eq('untested')
    end
  end

  it 'retains the existing connection, release assignments, remote references, and history' do
    release = build_release_graph
    connection = release.provider_assignments.find_by!(role: 'publishing').provider_connection
    event_ids = release.release_events.ids
    complete(connection)

    expect(release.provider_assignments.find_by!(role: 'publishing').provider_connection_id).to eq(connection.id)
    expect(release.remote_snapshots.sole.provider_connection_id).to eq(connection.id)
    expect(release.release_events.ids).to eq(event_ids)
    expect(connection.reload.identity_key).to eq('synthetic-publishing')
  end

  it 'checks the completed legacy model with its saved credentials' do
    connection = legacy_connection('ai')
    complete(connection)
    request = stub_request(:get, 'https://api.openai.com/v1/models/synthetic-model')
      .with(headers: { 'Authorization' => 'Bearer synthetic-private-credential' })
      .to_return(body: { id: 'synthetic-model', object: 'model' }.to_json)
    Settings::TestConnection.call(connection_id: connection.id)

    expect(connection.reload.check_code).to eq('model_read')
    expect(request).to have_been_requested.once
  end

  it 'repairs a partially configured connection and encrypts the completed credentials' do
    connection = legacy_connection(credentials: { api_key: 'old-private-value' }, credentials_version: 1)
    Settings::TestConnection.call(connection_id: connection.id)
    expect(connection.reload.check_code).to eq('unconfigured')
    complete(connection, expected_version: 1)
    stored = ApplicationRecord.connection.select_value("SELECT credentials FROM provider_connections WHERE id = #{connection.id}")

    expect(connection.reload.endpoint).to eq('https://c411.org')
    expect(stored).not_to include('synthetic-private-credential')
    expect(connection.check_code).to be_nil
  end

  it 'preserves all fields when the model or identity confirmation is invalid' do
    connection = legacy_connection('ai')
    expect { complete(connection, options: { model: '../invalid' }) }.to raise_error(Settings::ConnectionConfig::Invalid)
    expect { complete(connection, confirm_identity: false) }.to raise_error(Settings::ConnectionConfig::Invalid)

    expect(connection.reload.endpoint).to be_nil
    expect(connection.credentials).to be_nil
    expect(connection.credentials_version).to eq(0)
  end

  it 'rejects stale and repeated completion forms' do
    connection = legacy_connection
    expect { complete(connection, expected_version: 1) }.to raise_error(Settings::RotateCredentials::Conflict)
    complete(connection)

    expect { complete(connection) }.to raise_error(Settings::RotateCredentials::Conflict)
    expect { complete(connection, expected_version: 1) }.to raise_error(Settings::RotateCredentials::Conflict)
  end

  it 'keeps an existing endpoint immutable during completion' do
    connection = legacy_connection('torrent_client', endpoint: 'http://original.test:8112')
    expect { complete(connection) }.to raise_error(Settings::ConnectionConfig::Invalid, /adresse/)
    complete(connection, endpoint: 'http://original.test:8112')

    expect(connection.reload.endpoint).to eq('http://original.test:8112')
    expect { connection.update!(endpoint: 'http://different.test:8112') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'directs incomplete connections to atomic setup instead of partial rotation or model updates' do
    connection = legacy_connection('ai')

    expect { Settings::RotateCredentials.call(connection_id: connection.id, expected_version: 0, confirm_identity: true, credentials: { api_key: 'new' }) }
      .to raise_error(Settings::ConnectionConfig::Invalid, /Complétez/)
    expect { Settings::ConfigureConnection.call(connection_id: connection.id, expected_version: 0, options: { model: 'synthetic-model' }) }
      .to raise_error(Settings::ConnectionConfig::Invalid, /Complétez/)
  end
end
