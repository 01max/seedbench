require "rails_helper"

RSpec.describe Settings::ConfigureConnection do
  it "changes the AI model while retaining credentials and identity" do
    record = create_connection("ai")
    described_class.call(connection_id: record.id, expected_version: 1, options: { model: "another-model" })

    expect(record.reload.options).to eq("model" => "another-model")
    expect(record.credentials).to eq("api_key" => "synthetic-private-credential")
    expect(record.identity_key).to eq("synthetic-account")
    expect(record.check_status).to eq("untested")
  end

  it "rejects stale options and options for other providers" do
    record = create_connection("ai")
    expect { described_class.call(connection_id: record.id, expected_version: 0, options: { model: "older" }) }.to raise_error(Settings::RotateCredentials::Conflict)
    other = create_connection
    expect { described_class.call(connection_id: other.id, expected_version: 1, options: {}) }.to raise_error(Settings::ConnectionConfig::Invalid)
  end
end
