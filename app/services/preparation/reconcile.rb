module Preparation
  class Reconcile
    def self.call(operation:)
      move = PayloadMove.find_by(workflow_operation_id: operation.id)
      return unless move && %w[reserved moved].include?(move.state)

      paths = Paths.new
      paths.synchronize(payload_id: move.payload_revision_id) do
        Journal.call(move: move, paths: paths)
        if operation.input_revision != operation.release.reload.input_revision
          move.update!(state: move.reload.state == 'moved' ? 'completed' : 'cancelled')
        end
      end
    end
  end
end
