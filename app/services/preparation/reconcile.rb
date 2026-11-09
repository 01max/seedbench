module Preparation
  class Reconcile
    class << self
      def call(operation:)
        move = PayloadMove.find_by(workflow_operation_id: operation.id)
        return unless move && %w[reserved moved].include?(move.state)

        paths = Paths.new
        paths.synchronize(payload_id: move.payload_revision_id) { reconcile(operation, move, paths) }
      end

      private

      def reconcile(operation, move, paths)
        obsolete = operation.input_revision != operation.release.reload.input_revision
        return move.update!(state: 'cancelled') if obsolete && unmoved?(move, paths)

        Journal.call(move: move, paths: paths)
        move.update!(state: 'completed') if obsolete && move.reload.state == 'moved'
      end

      def unmoved?(move, paths)
        return false unless move.state == 'reserved' && move.source_locator != move.destination_locator

        source = paths.path(move.source_locator, missing: true)
        return false unless source.exist?

        verify_source!(move, paths, source)
        true
      end

      def verify_source!(move, paths, source)
        root = paths.root.stat
        raise Failure.new(:mapping_changed) unless [ root.dev, root.ino ] == [ move.root_device, move.root_inode ]

        identity = Identity.call(path: source, payload: move.payload_revision)
        raise Failure.new(:payload_changed) unless [ identity.dev, identity.ino ] == [ move.source_device, move.source_inode ]

      end
    end
  end
end
