require "rails_helper"

RSpec.describe Releases::Save do
  let(:release) { build_release_graph }

  def save(changes)
    described_class.call(release_id: release.id, expected_revision: 0, changes: changes)
  end

  it "atomically persists full human text, reviewed facts and one input revision", :aggregate_failures do
    save(title: "Reviewed title", isbn: "Unverified candidate", bbcode: "[b]Entire human text[/b]", nfo: "Full NFO\nKept intact")

    expect(release.reload.input_revision).to eq(1)
    expect(release.title).to eq("Reviewed title")
    expect(release.reviewed_facts.where(field: "title").order(:number).last.value).to eq("Reviewed title")
    expect(Releases::EditorValues.call(release: release)).to include("nfo" => "Full NFO\nKept intact", "bbcode" => "[b]Entire human text[/b]")
    expect(release.content_revisions.where(kind: "bbcode").order(:number).last.origin).to eq("human")
  end

  it "does not create revisions or events for unchanged values" do
    save(title: release.title, bbcode: "Human text")

    expect(release.reload.input_revision).to eq(0)
    expect(release.content_revisions.count).to eq(1)
    expect(release.release_events.count).to eq(1)
  end

  it "rejects an older autosave arriving after a newer save" do
    save(bbcode: "Newer human text")

    expect { save(bbcode: "Older text") }.to raise_error(Releases::RevisionConflict)
    expect(Releases::EditorValues.call(release: release.reload).fetch("bbcode")).to eq("Newer human text")
  end

  it "rolls back content and facts when the event fails" do
    release
    allow(Releases::RecordEvent).to receive(:call).and_raise("Synthetic event failure")

    expect { save(title: "Changed", nfo: "New NFO") }.to raise_error("Synthetic event failure")
    expect(release.reload.title).to eq("Synthetic book")
    expect(release.content_revisions.count).to eq(1)
    expect(release.reviewed_facts.count).to eq(1)
  end

  it "rejects invalid, oversized and unimplemented fields without losing content" do
    [ { title: "" }, { title: 12 }, { bbcode: "a" * 250_001 }, { inspection_state: "succeeded" } ].each do |changes|
      expect { save(changes) }.to raise_error(described_class::InvalidChanges)
    end
    expect(release.reload.input_revision).to eq(0)
  end

  it "permits text on an unlinked shell but requires a payload for edition facts" do
    shell = Releases::Create.call(title: "Unlinked")
    described_class.call(release_id: shell.id, expected_revision: 0, changes: { bbcode: "Local draft text" })

    expect(shell.content_revisions.sole.body).to eq("Local draft text")
    expect do
      described_class.call(release_id: shell.id, expected_revision: 1, changes: { isbn: "Candidate" })
    end.to raise_error(described_class::InvalidChanges)
  end
end
