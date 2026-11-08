require "rails_helper"

RSpec.describe Releases::AcknowledgeFinding do
  let(:release) { build_release_graph }
  let(:finding) { release.findings.find_by!(code: "edition_uncertain", number: 1) }

  it "rejects warning acknowledgements tied to an older payload" do
    release.payload_revisions.create!(number: 2, original_filename: "new.epub", format: "epub", size_bytes: 20, sha256: "b" * 64, locator: "staging/new.epub")

    expect { acknowledge(true) }.to raise_error(described_class::StaleFinding)
    expect(Releases::Snapshot.call(release: release).findings).to be_empty
  end

  def acknowledge(checked, **options)
    described_class.call(release_id: release.id, finding_id: finding.id, number: finding.number,
      expected_revision: 0, acknowledged: checked, **options)
  end

  it "reverses uncertainty acknowledgements without changing the finding" do
    acknowledge(false)
    acknowledge(true)

    expect(finding.finding_acknowledgements.order(:id).pluck(:acknowledged)).to eq([ true, false, true ])
    expect(finding.reload.severity).to eq("uncertainty")
  end

  it "does not duplicate an identical acknowledgement" do
    acknowledge(true)

    expect(finding.finding_acknowledgements.count).to eq(1)
  end

  it "requires a new acknowledgement when the finding is materially revised" do
    newer = release.findings.create!(payload_revision: release.payload_revisions.sole, code: finding.code, number: 2,
      severity: "uncertainty", message: "Changed evidence", input_revision: 0)

    expect { acknowledge(true) }.to raise_error(described_class::StaleFinding)
    expect(newer.finding_acknowledgements.count).to eq(0)
  end

  it "never permits accepting a deterministic failure" do
    failed = release.findings.create!(payload_revision: release.payload_revisions.sole, code: "invalid_structure", number: 1,
      severity: "failure", message: "Corrupt file", input_revision: 0)

    expect { acknowledge(true, finding_id: failed.id) }.to raise_error(described_class::NotUncertain)
    expect(failed.finding_acknowledgements.count).to eq(0)
  end

  it "rejects an old edit revision or a finding owned by another release" do
    expect { acknowledge(false, expected_revision: 5) }.to raise_error(Releases::RevisionConflict)
    another = Releases::Create.call
    expect { acknowledge(false, release_id: another.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
