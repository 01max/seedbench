require "digest"

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
      raise StorageFailure, "Stockage indisponible. Vérifiez l’espace libre et les droits du dossier monté."
    ensure
      File.unlink(@path) if @owns_file && !@completed && @path.exist?
    end

    private

    def validate_upload!
      raise InvalidUpload, "Choisissez un fichier EPUB, PDF ou MOBI." unless @upload.respond_to?(:original_filename) && @upload.respond_to?(:read)

      @filename = @upload.original_filename.to_s
      raise InvalidUpload, "Le nom du fichier est invalide." if @filename.blank? || !@filename.valid_encoding? || @filename.match?(%r{[\\/\x00-\x1f\x7f]})

      @format = File.extname(@filename).delete_prefix(".").downcase
      raise InvalidUpload, "Format non pris en charge : choisissez EPUB, PDF ou MOBI." unless FORMATS.include?(@format)
    end

    def staging_directory
      root = Rails.application.config.x.storage.fetch(:payload).realpath
      directory = root.join("staging")
      begin
        Dir.mkdir(directory, 0o700)
      rescue Errno::EEXIST
        raise StorageFailure, "Le dossier de dépôt doit être un dossier privé sans lien symbolique." if directory.symlink? || !directory.directory?
      end
      directory
    end

    def write_bytes
      digest = Digest::SHA256.new
      size = 0
      @upload.rewind
      File.open(@path, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o600) do |output|
        @owns_file = true
        size = copy_chunks(output, digest)
        output.flush
        output.fsync
      end
      raise InvalidUpload, "Le fichier est vide." if size.zero?

      [ size, digest.hexdigest ]
    end

    def copy_chunks(output, digest)
      size = 0
      while (chunk = @upload.read(CHUNK_BYTES)) && !chunk.empty?
        size += chunk.bytesize
        raise InvalidUpload, "Le fichier dépasse la limite de 100 Mio." if size > MAX_BYTES

        output.write(chunk)
        digest.update(chunk)
      end
      size
    end
  end
end
