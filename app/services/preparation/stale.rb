module Preparation
  # Marks preparation stale after an input change and closes a journal entry when its move already
  # happened.
  class Stale
    def self.call(operation:)
      operation.release.update!(preparation_state: 'stale')
      move = PayloadMove.find_by(workflow_operation_id: operation.id)
      move.update!(state: 'completed') if move&.state == 'moved'
    end
  end
end
