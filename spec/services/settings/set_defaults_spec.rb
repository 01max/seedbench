require "rails_helper"

RSpec.describe Settings::SetDefaults do
  def choices(connection = nil)
    Providers::Catalog::ROLES.keys.index_with { |role| role == "publishing" ? connection&.id : nil }
  end

  it "records defaults and the AI choice on future releases only" do
    old = Releases::Create.call
    connection = create_connection
    described_class.call(automatic_ai: false, connection_ids: choices(connection), expected_revision: 0)
    current = Releases::Create.call

    expect(old.reload).to be_automatic_ai
    expect(old.provider_assignments.pluck(:provider_connection_id)).to all(be_nil)
    expect(current).not_to be_automatic_ai
    expect(current.provider_assignments.find_by!(role: "publishing").provider_connection).to eq(connection)
    expect(WorkflowOperation.count).to eq(0)
  end

  it "retains a release's connection after a default switch and credential rotation" do
    first = create_connection
    second = create_connection(identity: "second-account")
    described_class.call(automatic_ai: true, connection_ids: choices(first), expected_revision: 0)
    release = Releases::Create.call
    described_class.call(automatic_ai: false, connection_ids: choices(second), expected_revision: 1)
    Settings::RotateCredentials.call(connection_id: first.id, expected_version: 1, confirm_identity: true, credentials: { api_key: "replacement" })

    expect(release.provider_assignments.find_by!(role: "publishing").provider_connection_id).to eq(first.id)
    expect(release.reload).to be_automatic_ai
    expect(Releases::Create.call.provider_assignments.find_by!(role: "publishing").provider_connection_id).to eq(second.id)
  end

  it "rolls back partial defaults on a role mismatch and rejects stale settings" do
    ai = create_connection("ai")
    expect { described_class.call(automatic_ai: false, connection_ids: choices(ai), expected_revision: 0) }.to raise_error(described_class::Invalid)
    expect(ProviderDefault.count).to eq(0)
    expect(OperatorPreference.count).to eq(0)
    described_class.call(automatic_ai: true, connection_ids: choices, expected_revision: 0)
    expect { described_class.call(automatic_ai: false, connection_ids: choices, expected_revision: 0) }.to raise_error(described_class::Conflict)
  end

  it "rejects incomplete roles and invalid AI flags" do
    expect { described_class.call(automatic_ai: true, connection_ids: {}, expected_revision: 0) }.to raise_error(described_class::Invalid)
    expect { described_class.call(automatic_ai: nil, connection_ids: choices, expected_revision: 0) }.to raise_error(described_class::Invalid)
  end
end
