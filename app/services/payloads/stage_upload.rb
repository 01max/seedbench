require 'digest'

module Payloads
  class StageUpload
    class InvalidUpload < StandardError; end
    class StorageFailure < StandardError; end
    Staged = Data.define(:path, :locator, :filename, :format, :size, :sha256)
    MAX_BYTES = 100 * 1024 * 1024
    CHUNK_BYTES = 64 * 1024
    FORMATS = %w[epub pdf mobi].freeze

    def self.call(upload:)
      new(upload).call
    end

    def initialize(upload)
      @upload = upload
    end

    def call
      validate_upload!
      @path = staging_directory.join("#{SecureRandom.uuid}.#{@format}")
      size, sha256 = write_bytes
      @completed = true
      Staged.new(path: @path, locator: "staging/#{@path.basename}", filename: @filename,
        format: @format, size: size, sha256: sha256)
    rescue SystemCallError, IOError
      raise StorageFailure, I18n.t('workbench.uploads.errors.unavailable_storage')
    ensure
      File.unlink(@path) if @owns_file && !@completed && @path.exist?
    end

    private

    def validate_upload!
      raise InvalidUpload, I18n.t('workbench.uploads.errors.choose_file') unless @upload.respond_to?(:original_filename) && @upload.respond_to?(:read)

      @filename = @upload.original_filename.to_s
      raise InvalidUpload, I18n.t('workbench.uploads.errors.invalid_filename') if @filename.blank? || !@filename.valid_encoding? || @filename.match?(%r{[\\/\x00-\x1f\x7f]})

      @format = File.extname(@filename).delete_prefix('.').downcase
      raise InvalidUpload, I18n.t('workbench.uploads.errors.unsupported_format') unless FORMATS.include?(@format)
    end

    def staging_directory
      root = Rails.application.config.x.storage.fetch(:payload).realpath
      directory = root.join('staging')
      begin
        Dir.mkdir(directory, 0o700)
      rescue Errno::EEXIST
        raise StorageFailure, I18n.t('workbench.uploads.errors.unsafe_directory') if directory.symlink? || !directory.directory?
      end
      directory
    end

    def write_bytes
      digest = Digest::SHA256.new
      size = 0
      @upload.rewind
      File.open(@path, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o600) do |output|
        @owns_file = true
        output.binmode
        size = copy_chunks(output, digest)
        output.flush
        output.fsync
      end
      raise InvalidUpload, I18n.t('workbench.uploads.errors.empty_file') if size.zero?

      [ size, digest.hexdigest ]
    end

    def copy_chunks(output, digest)
      size = 0
      while (chunk = @upload.read(CHUNK_BYTES)) && !chunk.empty?
        size += chunk.bytesize
        raise InvalidUpload, I18n.t('workbench.uploads.errors.too_large', size: MAX_BYTES / 1.megabyte) if size > MAX_BYTES

        output.write(chunk)
        digest.update(chunk)
      end
      size
    end
  end
end
