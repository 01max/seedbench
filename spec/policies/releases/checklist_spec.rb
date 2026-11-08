require "rails_helper"

RSpec.describe Releases::Checklist do
  it "shows all required and optional steps without manufacturing completed inspection" do
    release = Releases::Create.call(title: "Synthetic")
    items = described_class.call(release: release).index_by(&:key)

    expect(items.keys).to include("inspection", "edition_review", "cover", "text_review", "content", "preparation", "duplicates", "publication", "seeding", "draft", "ai")
    expect(items.fetch("inspection").state).to eq("pending")
    expect(items.fetch("draft").required).to be(false)
    expect(items.fetch("ai").required).to be(false)
  end

  it "keeps mechanical failures blocked despite all manual marks" do
    release = build_release_graph
    release.update!(inspection_state: "succeeded")
    release.findings.create!(payload_revision: release.payload_revisions.sole, code: "corrupt", number: 1, severity: "failure", message: "Corrupt file", input_revision: 0)
    Releases::MarkCheck::LABELS.each_key { |key| Releases::MarkCheck.call(release_id: release.id, key: key, checked: true, expected_revision: 0) }
    items = described_class.call(release: release).index_by(&:key)

    expect(items.fetch("text_review").state).to eq("done")
    expect(items.fetch("inspection").state).to eq("blocked")
    expect(items.fetch("content").state).to eq("pending")
  end

  it "derives prepared, hosted, duplicate and observed outcome states from persisted records" do
    release = build_release_graph
    release.update!(inspection_state: "succeeded", preparation_state: "prepared", publication_state: "published", seeding_state: "succeeded")
    items = described_class.call(release: release).index_by(&:key)

    %w[inspection preparation cover duplicates publication seeding draft].each do |key|
      expect(items.fetch(key).state).to eq("done")
    end
    expect(items.fetch("finding_#{release.findings.sole.id}").checked).to be(true)
  end

  it "requires review again for a new uncertainty revision" do
    release = build_release_graph
    release.findings.create!(payload_revision: release.payload_revisions.sole, code: release.findings.sole.code, number: 2,
      severity: "uncertainty", message: "New observation", input_revision: 0)
    warnings = described_class.call(release: release).select(&:finding)

    expect(warnings.sole.checked).to be(false)
    expect(warnings.sole.finding.number).to eq(2)
  end
end
