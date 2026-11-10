require 'digest'

module Preparation
  class Identity
    class << self
      def call(path:, payload:)
        File.open(path, File::RDONLY | File::NOFOLLOW) do |file|
          before = file.stat
          validate_file!(before, payload)
          raise Failure.new(:payload_changed) unless Digest::SHA256.file(file).hexdigest == payload.sha256
          raise Failure.new(:payload_changed) unless fingerprint(before) == fingerprint(file.stat) && File.identical?(path, file)

          before
        end
      rescue SystemCallError, IOError
        raise Failure.new(:storage_unavailable)
      end

      private

      def validate_file!(stat, payload)
        raise Failure.new(:payload_changed) unless stat.file? && stat.nlink == 1 && stat.size == payload.size_bytes
      end

      def fingerprint(stat)
        [ stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime ]
      end
    end
  end
end
