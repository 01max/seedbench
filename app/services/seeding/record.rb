module Seeding
  class Record
    def self.call(operation:, result:)
      operation.release.update!(seeding_state: result.fetch('status'))
      Releases::RecordEvent.call(release_id: operation.release_id, name: 'seeding.observed', data: result.merge('operation_id' => operation.id))
      result
    end
  end
end
