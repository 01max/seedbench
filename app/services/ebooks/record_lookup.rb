module Ebooks
  class RecordLookup
    def self.call(operation:, result:)
      result['candidates'] = Candidates.call(report: result)
      evidence = operation.release.evidence_items.create!(payload_revision_id: operation.parameters.fetch('payload_revision_id'),
        evidence_key: "edition-#{operation.id}", kind: 'edition_record', source: 'Open Library', captured_at: Time.current,
        input_revision: operation.input_revision, data: result)
      Findings.call(release: operation.release, payload: evidence.payload_revision)
      { evidence_id: evidence.id, found: result['lookup_error'].nil? }
    end
  end
end
