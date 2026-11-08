require "rails_helper"

RSpec.describe Releases::Intake do
  after { FileUtils.rm_rf(Rails.application.config.x.storage.fetch(:payload).join("staging")) }

  it "stages supported formats independently and reports each rejected file", :aggregate_failures do
    uploads = %w[Book.epub Book.pdf Book.mobi Bad.zip].map { |name| ebook_upload(name) }
    result = described_class.call(uploads: uploads)

    expect(result.releases.size).to eq(3)
    expect(result.errors.map(&:filename)).to eq([ "Bad.zip" ])
    expect(PayloadRevision.pluck(:format)).to contain_exactly("epub", "pdf", "mobi")
    expect(ProviderAssignment.count).to eq(12)
    expect(WorkflowOperation.count).to eq(0)
  end

  it "records original identity and preserves staged bytes on the configured mount" do
    release = described_class.call(uploads: [ ebook_upload("Titre.PDF") ]).releases.sole
    payload = release.payload_revisions.sole
    path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)

    expect(payload.attributes).to include("original_filename" => "Titre.PDF", "size_bytes" => 22, "sha256" => Digest::SHA256.hexdigest("Synthetic ebook bytes\n"))
    expect(path.binread).to eq("Synthetic ebook bytes\n")
    expect(path.stat.mode & 0o777).to eq(0o600)
    expect(release.inspection_state).to eq("pending")
  end

  it "removes only the unaccepted stage when database persistence fails" do
    allow(Releases::RecordEvent).to receive(:call).with(release_id: anything, name: "payload.staged", actor: "operator", data: anything).and_raise("Synthetic database failure")
    allow(Releases::RecordEvent).to receive(:call).with(release_id: anything, name: "release.created", actor: "operator").and_call_original

    expect { described_class.call(uploads: [ ebook_upload ]) }.to raise_error("Synthetic database failure")
    expect(Release.count).to eq(0)
    expect(Rails.application.config.x.storage.fetch(:payload).glob("staging/*")).to be_empty
  end

  it "requires a bounded nonempty batch" do
    [ [], Array.new(51) ].each do |uploads|
      expect { described_class.call(uploads: uploads) }.to raise_error(described_class::InvalidBatch)
    end
  end
end
