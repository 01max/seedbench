require "rails_helper"

RSpec.describe Ebooks::Parser do
  let(:directory) { Pathname.new(Dir.mktmpdir("ebook-fixtures-")) }

  def inspect_fixture(name: "book.epub")
    upload = Rack::Test::UploadedFile.new(directory.join(name), "application/octet-stream")
    release = Releases::Intake.call(uploads: [ upload ]).releases.sole
    payload = release.payload_revisions.sole
    [ release, payload, described_class.call(payload: payload) ]
  end

  before do
    system("python3", Rails.root.join("script/ebooks/fixtures.py").to_s, directory.to_s, exception: true)
  end

  after { FileUtils.remove_entry(directory) }

  it "measures an EPUB without changing its bytes or reviewing metadata" do
    release, payload, report = inspect_fixture
    expect(report).to include("error" => nil, "structure" => include("spine_documents" => 1))
    expect(report.fetch("metadata")).to include(include("field" => "title", "value" => "Synthetic book"))
    expect(report.fetch("samples").first).to include("source" => "chapter.xhtml", "text" => include("Sample text"))
    expect(Digest::SHA256.file(Rails.application.config.x.storage.fetch(:payload).join(payload.locator)).hexdigest).to eq(payload.sha256)
    expect(release.reviewed_facts).to be_empty
  end

  it "applies the background result once and retains cover candidates separately" do
    release, payload, = inspect_fixture
    operation = release.workflow_operations.sole
    2.times { Workflows::Execute.call(operation_id: operation.id) }
    expect(release.reload.inspection_state).to eq("succeeded")
    expect(release.evidence_items.sole.data.fetch("covers").first).to include("width" => 600, "height" => 900)
    expect(release.cover_revisions).to be_empty
    expect(payload.reload.sha256).to eq(Digest::SHA256.file(directory.join("book.epub")).hexdigest)
  end

  it "requeues an inspection made stale by an edit" do
    release, = inspect_fixture
    operation = release.workflow_operations.sole
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { title: "Human title" })
    Workflows::Execute.call(operation_id: operation.id)
    expect(operation.reload.state).to eq("stale")
    expect(release.workflow_operations.order(:id).last).to have_attributes(state: "pending", input_revision: 1)
    expect(release.reload.title).to eq("Human title")
  end

  it "reports a corrupt archive truthfully" do
    directory.join("bad.epub").binwrite("not a zip")
    _, _, report = inspect_fixture(name: "bad.epub")
    expect(report).to eq("error" => "corrupt")
  end
end
