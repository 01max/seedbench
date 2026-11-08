require "rails_helper"

RSpec.describe Releases::Create do
  it "creates a local release with explicit unconfigured assignments and one event" do
    release = described_class.call(title: "Synthetic")

    expect(release.provider_assignments.pluck(:role)).to match_array(Releases::Create::ROLES)
    expect(release.provider_assignments.pluck(:provider_connection_id)).to all(be_nil)
    expect(release.release_events.sole.name).to eq("release.created")
    expect(release).to be_automatic_ai
  end

  it "rolls back creation when history cannot be written" do
    allow(Releases::RecordEvent).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

    expect { described_class.call }.to raise_error(ActiveRecord::StatementInvalid)
    expect(Release.count).to eq(0)
  end
end
