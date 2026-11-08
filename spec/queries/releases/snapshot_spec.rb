require "rails_helper"

RSpec.describe Releases::Snapshot do
  it "shows the latest full human text while retaining history and source identity" do
    release = build_release_graph
    release.content_revisions.create!(kind: "bbcode", number: 2, body: "New human text", origin: "human", input_revision: 0)
    snapshot = described_class.call(release: release)

    expect(snapshot.contents.fetch("bbcode").body).to eq("New human text")
    expect(snapshot.payload.sha256).to eq("a" * 64)
    expect(snapshot.snapshots.fetch("draft").remote_id).to eq("synthetic-draft")
    expect(snapshot.findings.sole.message).to eq("Synthetic uncertainty")
    expect(snapshot.events.sole.name).to eq("release.created")
  end
end
