module Ebooks
  class Record
    def self.call(operation:, result:)
      result["candidates"] = Candidates.call(report: result)
      release = operation.release
      payload = release.payload_revisions.find(operation.parameters.fetch("payload_revision_id"))
      evidence = evidence_for(operation, payload, result)
      Findings.call(release: release, payload: payload)
      release.update!(inspection_state: result["error"] ? "failed" : "succeeded")
      { evidence_id: evidence.id, failed: result["error"].present? }
    end

    def self.evidence_for(operation, payload, result)
      operation.release.evidence_items.create!(payload_revision: payload, evidence_key: "inspection-#{operation.id}",
        kind: "inspection", source: "#{payload.format.upcase} · #{payload.original_filename}", captured_at: Time.current,
        input_revision: operation.input_revision, data: result)
    end
    private_class_method :evidence_for
  end
end
