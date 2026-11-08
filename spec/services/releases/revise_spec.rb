require "rails_helper"

RSpec.describe Releases::Revise do
  let(:release) { Releases::Create.call(title: "Original") }

  it "commits a new input revision and an ordered event together" do
    described_class.call(release_id: release.id, expected_revision: 0, changes: { title: "Reviewed" })

    expect(release.reload.title).to eq("Reviewed")
    expect(release.input_revision).to eq(1)
    expect(release.release_events.order(:sequence).pluck(:name)).to eq(%w[release.created release.revised])
  end

  it "preserves the newer edit when an older revision arrives" do
    described_class.call(release_id: release.id, expected_revision: 0, changes: { author: "Reviewed author" })

    expect { described_class.call(release_id: release.id, expected_revision: 0, changes: { author: "Older author" }) }
      .to raise_error(Releases::RevisionConflict) { |error| expect(error.actual_revision).to eq(1) }
    expect(release.reload.author).to eq("Reviewed author")
  end

  it "does not create another revision for an unchanged edit" do
    described_class.call(release_id: release.id, expected_revision: 0, changes: { title: "Original" })

    expect(release.reload.input_revision).to eq(0)
    expect(release.release_events.count).to eq(1)
  end

  it "rolls back the edit if its event fails" do
    id = release.id
    allow(Releases::RecordEvent).to receive(:call).and_raise(ActiveRecord::StatementInvalid)

    expect { described_class.call(release_id: id, expected_revision: 0, changes: { title: "Lost" }) }
      .to raise_error(ActiveRecord::StatementInvalid)
    expect(release.reload.title).to eq("Original")
  end

  it "rejects workflow-state changes through the local edit interface" do
    expect { described_class.call(release_id: release.id, expected_revision: 0, changes: { publication_state: "published" }) }
      .to raise_error(described_class::InvalidChanges)
  end
end
