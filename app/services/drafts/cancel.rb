module Drafts
  class Cancel
    def self.call(operation:)
      write = operation.draft_write
      return unless write && write.state == 'pending'
      write.update!(state: 'failed', error_code: 'input_changed')
    end
  end
end
