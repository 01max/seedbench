module Preparation
  class Move
    def self.call(operation:, names:, paths: Paths.new)
      paths.synchronize(payload_id: operation.parameters.fetch('payload_revision_id')) do
        new(operation, names, paths).call
      end
    end

    def initialize(operation, names, paths)
      @operation, @names, @paths = operation, names, paths
      @attempt = operation.attempt_token
      @payload = operation.release.payload_revisions.find(operation.parameters.fetch('payload_revision_id'))
    end

    def call
      Guard.call(operation: @operation, attempt: @attempt)
      @move = Reserve.call(operation: @operation, payload: @payload, destination: @names.payload, paths: @paths)
      Journal.call(move: @move, paths: @paths)
      return @move if @move.reload.state == 'moved'

      Guard.call(operation: @operation, attempt: @attempt)
      rename
      Journal.call(move: @move, paths: @paths)
    end

    private

    def rename
      source = @paths.path(@move.source_locator)
      identity = Identity.call(path: source, payload: @payload)
      raise Failure.new(:payload_changed) unless [ identity.dev, identity.ino ] == [ @move.source_device, @move.source_inode ]

      destination = @paths.path(@move.destination_locator, missing: true)
      Rename.call(source: source, destination: destination)
    end
  end
end
