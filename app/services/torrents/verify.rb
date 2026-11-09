require 'digest'

module Torrents
  class Verify
    def self.call(torrent:, payload_path:, payload:, name:)
      new(torrent, payload_path, payload, name).call
    end

    def initialize(torrent, payload_path, payload, name)
      @torrent, @payload_path, @payload, @name = torrent, payload_path, payload, name
    end

    def call
      Preparation::Identity.call(path: @payload_path, payload: @payload)
      metadata = decode
      @info = metadata.fetch('info')
      validate_inventory!
      verify_pieces!
      Preparation::Identity.call(path: @payload_path, payload: @payload)
      Digest::SHA1.hexdigest(Bencode.encode(@info))
    rescue Bencode::Invalid, KeyError, TypeError, NoMethodError
      raise Preparation::Failure.new(:invalid_torrent)
    end

    private

    def decode
      File.open(@torrent, File::RDONLY | File::NOFOLLOW) do |file|
        raise Preparation::Failure.new(:invalid_torrent) unless file.stat.file? && file.size.between?(1, Bencode::MAX_BYTES)

        Bencode.decode(file.read(Bencode::MAX_BYTES + 1))
      end
    end

    def validate_inventory!
      raise Preparation::Failure.new(:invalid_torrent) unless single_file? && matching_file?

      length = @info.fetch('piece length')
      valid = length.is_a?(Integer) && length.between?(16_384, 16_777_216) && (length & (length - 1)).zero?
      raise Preparation::Failure.new(:invalid_torrent) unless valid
    end

    def single_file?
      @info.is_a?(Hash) && @info['private'] == 1 && !@info.key?('files') && !@info.key?('meta version')
    end

    def matching_file?
      @info['name'] == @name.b && @info['length'] == @payload.size_bytes
    end

    def verify_pieces!
      length = @info.fetch('piece length')
      pieces = @info.fetch('pieces')
      expected = ((@payload.size_bytes + length - 1) / length) * 20
      raise Preparation::Failure.new(:invalid_torrent) unless pieces.is_a?(String) && pieces.bytesize == expected

      compare_pieces(length, pieces, expected)
    end

    def compare_pieces(length, pieces, expected)
      File.open(@payload_path, File::RDONLY | File::NOFOLLOW) do |file|
        offset = 0
        while (chunk = file.read(length))
          raise Preparation::Failure.new(:torrent_mismatch) unless Digest::SHA1.digest(chunk) == pieces.byteslice(offset, 20)

          offset += 20
        end
        raise Preparation::Failure.new(:torrent_mismatch) unless offset == expected
      end
    end
  end
end
