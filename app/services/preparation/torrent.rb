require 'tempfile'
require 'tmpdir'

module Preparation
  class Torrent
    Result = Data.define(:locator, :info_hash)

    def self.call(operation:, names:, paths: Paths.new)
      new(operation, names, paths).call
    end

    def initialize(operation, names, paths)
      @operation, @names, @paths = operation, names, paths
      @payload = operation.release.payload_revisions.find(operation.parameters.fetch('payload_revision_id'))
    end

    def call
      prepare_directory
      locator = "preparation-torrents/#{@operation.id}/#{@names.torrent}"
      destination = @paths.path(locator, kind: :state, missing: true)
      create(destination) unless destination.exist?
      info_hash = verify(destination)
      Result.new(locator: locator, info_hash: info_hash)
    end

    private

    def prepare_directory
      state = @paths.root(:state)
      raise Failure.new(:unsafe_path) if state == @paths.root || state.to_s.start_with?("#{@paths.root}/")

      @paths.directory('preparation-torrents')
      @paths.directory("preparation-torrents/#{@operation.id}")
    end

    def create(destination)
      Dir.mktmpdir('torrent-', @paths.root(:scratch)) do |directory|
        temporary = Pathname.new(directory).join('prepared.torrent')
        Torrents::Create.call(payload_path: @paths.path(@payload.locator), output: temporary)
        verify(temporary)
        persist(temporary, destination)
      end
    end

    def persist(temporary, destination)
      Tempfile.create('.torrent-', destination.parent) do |file|
        file.binmode.write(temporary.binread)
        file.flush
        file.fsync
        File.link(file.path, destination)
        File.open(destination.parent, &:fsync)
      end
    rescue Errno::EEXIST
      verify(destination)
    end

    def verify(path)
      Torrents::Verify.call(torrent: path, payload_path: @paths.path(@payload.locator), payload: @payload, name: @names.payload)
    end
  end
end
