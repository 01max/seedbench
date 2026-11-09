module Releases
  class Intake
    class InvalidBatch < StandardError; end
    Result = Data.define(:releases, :errors)
    Rejection = Data.define(:filename, :message)
    MAX_FILES = 50

    class << self
      def call(uploads:)
        raise InvalidBatch, I18n.t('workbench.uploads.errors.invalid_batch', count: MAX_FILES) unless uploads.is_a?(Array) && uploads.size.between?(1, MAX_FILES)

        releases, errors = [], []
        uploads.each do |upload|
          releases << accept(upload)
        rescue Payloads::StageUpload::InvalidUpload, Payloads::StageUpload::StorageFailure => error
          name = upload.respond_to?(:original_filename) ? upload.original_filename.to_s : I18n.t('workbench.uploads.missing_file')
          errors << Rejection.new(filename: name, message: error.message)
        end
        Result.new(releases: releases, errors: errors)
      end

      private

      def accept(upload)
        staged = Payloads::StageUpload.call(upload: upload)
        transaction_started = false
        Release.transaction do |transaction|
          transaction.after_rollback { discard(staged) }
          transaction_started = true
          persist(staged)
        end
      ensure
        discard(staged) if staged && !transaction_started
      end

      def persist(staged)
        release = Create.call(title: File.basename(staged.filename, File.extname(staged.filename)))
        release.payload_revisions.create!(number: 1, original_filename: staged.filename, format: staged.format,
          size_bytes: staged.size, sha256: staged.sha256, locator: staged.locator)
        RecordEvent.call(release_id: release.id, name: 'payload.staged', actor: 'operator',
          data: { format: staged.format, size_bytes: staged.size, sha256: staged.sha256 })
        Ebooks::Request.call(release: release, automatic: true)
        release
      end

      def discard(staged)
        File.unlink(staged.path) if staged.path.exist?
      end
    end
  end
end
