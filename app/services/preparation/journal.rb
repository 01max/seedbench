module Preparation
  class Journal
    def self.call(move:, paths: Paths.new)
      new(move, paths).call
    end

    def initialize(move, paths)
      @move, @paths = move, paths
      @payload = move.payload_revision
    end

    def call
      verify_root!
      source = @paths.path(@move.source_locator, missing: true)
      destination = @paths.path(@move.destination_locator, missing: true)
      return @move if source != destination && source.exist? && !destination.exist?
      raise Failure.new(:collision) if source != destination && source.exist?

      commit_destination(destination)
    end

    private

    def verify_root!
      stat = @paths.root.stat
      raise Failure.new(:mapping_changed) unless [ stat.dev, stat.ino ] == [ @move.root_device, @move.root_inode ]
    end

    def commit_destination(path)
      identity = Identity.call(path: path, payload: @payload)
      raise Failure.new(:payload_changed) unless [ identity.dev, identity.ino ] == [ @move.source_device, @move.source_inode ]

      sync_destination(path)
      persist_location
      @move
    end

    def sync_destination(path)
      File.chmod(0o640, path) if @move.source_locator.start_with?('staging/')
      File.open(path, File::RDONLY | File::NOFOLLOW, &:fsync)
      [ path.parent, @paths.path(@move.source_locator, missing: true).parent ].uniq.each do |directory|
        File.open(directory, &:fsync)
      end
    end

    def persist_location
      @payload.release.with_lock do
        @payload.reload
        raise Failure.new(:payload_changed) unless [ @move.source_locator, @move.destination_locator ].include?(@payload.locator)

        @payload.update!(locator: @move.destination_locator) unless @payload.locator == @move.destination_locator
        @move.update!(state: 'moved') unless @move.state == 'moved'
      end
    end
  end
end
