module Drafts
  class Record
    def self.call(operation:, result:)
      raise Failure.new(:invalid_response) unless result['write_id'] == operation.draft_write.id
      Releases::RecordEvent.call(release_id: operation.release_id, name: 'draft.write_observed', data: result)
      result
    end
  end
end
