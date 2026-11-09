require "tmpdir"

module RuntimeEbooks
  def self.prepare
    scratch = Rails.application.config.x.storage.fetch(:scratch)
    Dir.mktmpdir("runtime-ebook-", scratch) do |directory|
      code = "import sys,pathlib;sys.path.insert(0,'script/ebooks');import fixtures;fixtures.epub(pathlib.Path(sys.argv[1]))"
      system("python3", "-c", code, directory, exception: true)
      File.open(File.join(directory, "book.epub"), "rb") do |file|
        upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "runtime-inspection.epub", type: "application/epub+zip")
        release = Releases::Intake.call(uploads: [ upload ]).releases.sole
        scratch.join("runtime-inspection-id").write(release.id.to_s)
      end
    end
  end

  def self.verify
    id = Rails.application.config.x.storage.fetch(:scratch).join("runtime-inspection-id").read.to_i
    release = Release.find(id)
    payload = release.payload_revisions.sole
    evidence = release.evidence_items.where(kind: "inspection").sole
    path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)
    abort "Background inspection did not succeed" unless release.inspection_state == "succeeded" && release.workflow_operations.sole.state == "succeeded"
    abort "Inspection lost measured evidence" unless evidence.data.dig("structure", "spine_documents") == 1 && evidence.data.fetch("covers").first.fetch("width") == 600
    abort "Inspection changed payload bytes" unless path.size == payload.size_bytes && Digest::SHA256.file(path).hexdigest == payload.sha256
    abort "Inspection replaced human facts or selected a cover" if release.reviewed_facts.exists? || release.cover_revisions.exists?
    puts "Real worker inspected a synthetic EPUB; unchanged bytes, evidence and cover candidates survived recreation."
  end
end
