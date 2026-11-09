require "rails_helper"

RSpec.describe Releases::ReviewAction do
  it "saves the reviewed text before any action can be attempted" do
    release = Releases::Create.call(title: "Synthetic")
    expect do
      described_class.call(release_id: release.id, kind: "prepare", expected_revision: 0, changes: { bbcode: "Reviewed text" })
    end.to raise_error(described_class::Unavailable) { |error| expect(error.revision).to eq(1) }

    expect(release.content_revisions.sole.body).to eq("Reviewed text")
    expect(release.workflow_operations.count).to eq(0)
    expect(release.preparation_revisions.count).to eq(0)
  end

  it "rejects stale or unknown actions without applying different text" do
    release = Releases::Create.call
    expect do
      described_class.call(release_id: release.id, kind: "publish", expected_revision: 9, changes: { bbcode: "Stale" })
    end.to raise_error(Releases::RevisionConflict)
    expect do
      described_class.call(release_id: release.id, kind: "invented", expected_revision: 0, changes: { bbcode: "Unknown" })
    end.to raise_error(described_class::UnknownAction)
    expect(release.content_revisions.count).to eq(0)
  end
end
