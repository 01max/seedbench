require 'digest'
require 'tempfile'

module Covers
  class Asset
    class << self
      def store(bytes:, sha256:)
        paths = Preparation::Paths.new
        directory = paths.directory('cover-assets')
        locator = "cover-assets/#{sha256}"
        destination = paths.path(locator, kind: :state, missing: true)
        persist(directory, destination, bytes)
        locator
      rescue Errno::EEXIST
        read(locator: locator, sha256: sha256)
        locator
      rescue Preparation::Failure, SystemCallError, IOError
        raise Failure.new(:invalid_source), cause: nil
      end

      def read(locator:, sha256:)
        raise Failure.new(:invalid_source) unless sha256.to_s.match?(/\A[0-9a-f]{64}\z/)

        path = Preparation::Paths.new.path(locator, kind: :state)
        File.open(path, File::RDONLY | File::NOFOLLOW) do |file|
          read_verified(file, sha256)
        end
      rescue Preparation::Failure, SystemCallError, IOError
        raise Failure.new(:invalid_source), cause: nil
      end
      private

      def persist(directory, destination, bytes)
        Tempfile.create('cover-', directory) do |file|
          file.binmode.write(bytes)
          file.flush
          file.fsync
          File.link(file.path, destination)
        end
      end

      def read_verified(file, sha256)
        raise Failure.new(:invalid_source) unless file.stat.file? && file.size <= Fetch::MAX_BYTES

        bytes = file.read(Fetch::MAX_BYTES + 1)
        raise Failure.new(:invalid_source) unless Digest::SHA256.hexdigest(bytes) == sha256

        bytes
      end
    end
  end
end
