module Ebooks
  # Requests replacement inspection when a workflow discards a stale inspection result.
  class Refresh
    def self.call(operation:)
      Request.call(release: operation.release.reload, ocr: operation.parameters.fetch('ocr'), automatic: true)
    end
  end
end
