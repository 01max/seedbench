module Releases
  class Intake
    class InvalidBatch < StandardError; end
    Result = Data.define(:releases, :errors)
    Rejection = Data.define(:filename, :message)
    MAX_FILES = 50

    def self.call(uploads:)
      raise InvalidBatch, "Choisissez entre 1 et 50 fichiers." unless uploads.is_a?(Array) && uploads.size.between?(1, MAX_FILES)

      releases, errors = [], []
      uploads.each do |upload|
        releases << accept(upload)
      rescue Payloads::StageUpload::InvalidUpload, Payloads::StageUpload::StorageFailure => error
        name = upload.respond_to?(:original_filename) ? upload.original_filename.to_s : "Fichier manquant"
        errors << Rejection.new(filename: name, message: error.message)
      end
      Result.new(releases: releases, errors: errors)
    end

    def self.accept(upload)
      staged = Payloads::StageUpload.call(upload: upload)
      release = persist(staged)
      release
    ensure
      File.unlink(staged.path) if staged && !release && staged.path.exist?
    end
    private_class_method :accept

    def self.persist(staged)
      Release.transaction do
        release = Create.call(title: File.basename(staged.filename, File.extname(staged.filename)))
        release.payload_revisions.create!(number: 1, original_filename: staged.filename, format: staged.format,
          size_bytes: staged.size, sha256: staged.sha256, locator: staged.locator)
        RecordEvent.call(release_id: release.id, name: "payload.staged", actor: "operator",
          data: { format: staged.format, size_bytes: staged.size, sha256: staged.sha256 })
        release
      end
    end
    private_class_method :persist
  end
end
