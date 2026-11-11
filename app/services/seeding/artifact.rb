require 'tempfile'

module Seeding
  class Artifact
    Result = Data.define(:bytes, :trackers)

    def self.call(operation:, preparation:, bytes:)
      new(operation, preparation).call(bytes)
    end

    def initialize(operation, preparation)
      @operation, @preparation = operation, preparation
      @paths = Preparation::Paths.new
    end

    def call(bytes)
      trackers = verify_trackers(bytes)
      directory = private_directory
      Tempfile.create('.personalized-', directory) do |file|
        file.binmode.write(bytes)
        file.flush
        verify_payload(file.path)
        file.fsync
        File.link(file.path, directory.join("#{@operation.id}.torrent"))
        File.open(directory, &:fsync)
      end
      Result.new(bytes: bytes, trackers: trackers)
    rescue SystemCallError, IOError
      raise Failure.new(:artifact_storage), cause: nil
    end

    private

    def private_directory
      state, payload = @paths.root(:state), @paths.root
      raise Failure.new(:artifact_storage) if state == payload || state.to_s.start_with?("#{payload}/")

      directory = @paths.directory('personalized-torrents')
      raise Failure.new(:artifact_storage) unless (directory.stat.mode & 0o077).zero?

      directory
    end

    def verify_payload(file)
      payload = @preparation.payload_revision
      hash = Torrents::Verify.call(torrent: file, payload_path: @paths.path(payload.locator), payload: payload, name: @preparation.payload_name)
      raise Failure.new(:torrent_mismatch) unless hash == @operation.parameters.fetch('info_hash')
    end

    def verify_trackers(bytes)
      torrent = Torrents::Bencode.decode(bytes)
      primary = torrent.fetch('announce')
      others = torrent.fetch('announce-list', [])
      raise Failure.new(:torrent_tracker) unless others.is_a?(Array) && others.all?(Array)

      urls = [ primary, *others.flatten ].uniq
      raise Failure.new(:torrent_tracker) unless urls.all? { |url| c411_tracker?(url) }

      urls
    rescue Torrents::Bencode::Invalid, KeyError, TypeError, NoMethodError
      raise Failure.new(:torrent_tracker), cause: nil
    end

    def c411_tracker?(url)
      return false unless url.is_a?(String) && url.bytesize.between?(1, 2048)

      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && uri.userinfo.nil? && uri.fragment.nil? && uri.path.present? && c411_host?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    def c411_host?(host)
      host == 'c411.org' || host.to_s.end_with?('.c411.org')
    end
  end
end
