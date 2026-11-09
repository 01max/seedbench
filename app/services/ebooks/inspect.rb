module Ebooks
  class Inspect
    def self.call(operation:)
      release = operation.release
      release.with_lock do
        release.update!(inspection_state: 'running') if release.input_revision == operation.input_revision
      end
      payload = release.payload_revisions.find(operation.parameters.fetch('payload_revision_id'))
      Parser.call(payload: payload, ocr: operation.parameters.fetch('ocr'))
    end
  end
end
