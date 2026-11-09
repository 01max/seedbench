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

  after do
    FileUtils.remove_entry(directory)
    FileUtils.rm_rf(Rails.application.config.x.storage.fetch(:payload).join("staging"))
  end

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
    directory.join("bad.epub").binwrite("PK\x03\x04broken zip")
    _, _, report = inspect_fixture(name: "bad.epub")
    expect(report).to eq("error" => "corrupt")
  end

  it "measures PDF pages and source-linked text without changing the original" do
    _, payload, report = inspect_fixture(name: "book.pdf")
    expect(report).to include("error" => nil, "structure" => include("page_count" => 1, "ocr" => false))
    expect(report.fetch("samples")).to include(include("source" => "pdf:page:1", "text" => include("Synthetic PDF")))
    expect(payload.sha256).to eq(Digest::SHA256.file(directory.join("book.pdf")).hexdigest)
  end

  it "keeps OCR material outside the payload and removes temporary sidecars" do
    _, payload, = inspect_fixture(name: "scan.pdf")
    report = described_class.call(payload: payload, ocr: true)
    expect(report).to include("error" => nil, "structure" => include("pages_without_text_in_sample" => [ 1 ]))
    expect(report.fetch("samples")).to include(include("source" => "ocr:pdf:page:1", "text" => include("synthetique")))
    expect(Rails.application.config.x.storage.fetch(:scratch).glob("inspection-*")).to be_empty
    expect(payload.sha256).to eq(Digest::SHA256.file(directory.join("scan.pdf")).hexdigest)
  end


  context "with MOBI content" do
    before do
      system("python3", Rails.root.join("script/ebooks/fixtures.py").to_s, directory.to_s, "mobi", exception: true)
    end

    it "extracts metadata and text through Calibre after validating PalmDB" do
      _, payload, report = inspect_fixture(name: "book.mobi")
      expect(report).to include("error" => nil, "structure" => include("text_records" => be_positive))
      expect(report.fetch("metadata")).to include(include("field" => "title", "value" => "Synthetic book"))
      expect(report.fetch("samples").first.fetch("text")).to include("Sample text")
      expect(payload.sha256).to eq(Digest::SHA256.file(directory.join("book.mobi")).hexdigest)
    end

    it "rejects encrypted content before invoking conversion" do
      path = directory.join("book.mobi")
      bytes = path.binread
      first_record = bytes.byteslice(78, 4).unpack1("N")
      bytes[first_record + 12, 2] = [ 1 ].pack("n")
      path.binwrite(bytes)
      _, _, report = inspect_fixture(name: "book.mobi")
      expect(report).to eq("error" => "encrypted")
    end
  end

  context "with hostile or mislabeled files" do
    before do
      system("python3", Rails.root.join("script/ebooks/adversarial.py").to_s, directory.to_s, exception: true)
    end

    { "bomb.epub" => "resource_limit", "encrypted.epub" => "encrypted", "entity.epub" => "unsafe_xml", "utf16.epub" => "unsafe_xml",
      "missing.epub" => "missing_resource", "escape.epub" => "unsafe_reference", "disguised.pdf" => "signature_mismatch",
      "broken.mobi" => "corrupt", "encrypted.pdf" => "encrypted", "crc.epub" => "corrupt" }.each do |filename, error|
      it "reports #{filename} without changing its hash" do
        _, payload, report = inspect_fixture(name: filename)
        expect(report).to eq("error" => error)
        expect(payload.sha256).to eq(Digest::SHA256.file(directory.join(filename)).hexdigest)
      end
    end

    it "accepts an internal parent reference that stays inside the archive" do
      _, _, report = inspect_fixture(name: "nested.epub")
      expect(report.fetch("error")).to be_nil
    end
  end

  it "rejects payload locators outside the configured root" do
    _, payload, = inspect_fixture
    payload.locator = directory.join("book.epub").to_s
    expect(described_class.call(payload: payload)).to eq("error" => "payload_changed")
  end

  it "discards a late result and requests a fresh inspection after a human edit" do
    release, _, report = inspect_fixture
    operation = release.workflow_operations.sole
    token = Workflows::Claim.call(operation_id: operation.id)
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { presentation: "New human prose" })
    Workflows::Complete.call(operation_id: operation.id, attempt_token: token, result: report, apply: Ebooks::Record)
    expect(operation.reload.state).to eq("stale")
    expect(release.evidence_items).to be_empty
    expect(release.workflow_operations.order(:id).last).to have_attributes(input_revision: 1, state: "pending")
    expect(release.content_revisions.sole.body).to eq("New human prose")
  end

  it "keeps OCR and standard retries distinct after an input change" do
    release, = inspect_fixture(name: "book.pdf")
    ordinary = release.workflow_operations.sole
    ocr = Ebooks::Request.call(release: release, ocr: true)
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { notes: "New note" })
    [ ordinary, ocr ].each { |operation| Workflows::Execute.call(operation_id: operation.id) }
    pending = release.workflow_operations.where(state: "pending", input_revision: 1)
    expect(pending.map { |operation| operation.parameters.fetch("ocr") }).to contain_exactly(true, false)
    expect(pending.pluck(:request_key).uniq.size).to eq(2)
  end
end
