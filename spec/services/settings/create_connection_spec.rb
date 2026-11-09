require 'rails_helper'

RSpec.describe Settings::CreateConnection do
  it 'encrypts credentials while retaining the explicit provider identity' do
    record = create_connection
    stored = ApplicationRecord.connection.select_value("SELECT credentials FROM provider_connections WHERE id = #{record.id}")

    expect(stored).not_to include('synthetic-private-credential')
    expect(record.reload.credentials).to eq('api_key' => 'synthetic-private-credential')
    expect(record.check_status).to eq('untested')
    expect { ApplicationRecord.connection.execute("UPDATE provider_connections SET endpoint = 'https://different.invalid' WHERE id = #{record.id}") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it 'requires the implemented role and a credential-free supported address' do
    [ { role: 'other' }, { label: '' }, { identity_key: '' }, { endpoint: 'https://user:password@c411.org' },
      { endpoint: 'https://other.invalid' }, { endpoint: 'https://c411.org?key=secret' }, { endpoint: 'bad address' } ].each do |changes|
      expect { described_class.call(**connection_attributes.merge(changes)) }.to raise_error(Settings::ConnectionConfig::Invalid)
    end
  end

  it 'rejects invalid secrets and unimplemented options' do
    [ { credentials: {} }, { credentials: nil }, { credentials: { api_key: 'value', password: 'other' } },
      { options: nil }, { options: { prompt: 'arbitrary' } } ].each do |changes|
      expect { described_class.call(**connection_attributes.merge(changes)) }.to raise_error(Settings::ConnectionConfig::Invalid)
    end
    expect { described_class.call(**connection_attributes('image_host').merge(credentials: { api_key: 'bad' })) }.to raise_error(Settings::ConnectionConfig::Invalid)
    expect { described_class.call(**connection_attributes('ai').merge(options: { model: '../escape' })) }.to raise_error(Settings::ConnectionConfig::Invalid)
  end

  it 'prevents implicit identity replacement and only rotates against the current version' do
    record = create_connection
    expect { create_connection }.to raise_error(Settings::ConnectionConfig::Invalid, /existe déjà/)
    expect { Settings::RotateCredentials.call(connection_id: record.id, expected_version: 1, confirm_identity: false, credentials: { api_key: 'new' }) }.to raise_error(Settings::ConnectionConfig::Invalid)
    Settings::RotateCredentials.call(connection_id: record.id, expected_version: 1, confirm_identity: true, credentials: { api_key: 'new' })
    expect(record.reload.identity_key).to eq('synthetic-account')
    expect(record.credentials).to eq('api_key' => 'new')
    expect { Settings::RotateCredentials.call(connection_id: record.id, expected_version: 1, confirm_identity: true, credentials: { api_key: 'older' }) }.to raise_error(Settings::RotateCredentials::Conflict)
  end
end
