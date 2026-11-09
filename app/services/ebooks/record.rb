module Ebooks
  class Record
    def self.call(operation:, result:)
      result["candidates"] = Candidates.call(report: result)
      release = operation.release
      payload = release.payload_revisions.find(operation.parameters.fetch("payload_revision_id"))
      evidence = evidence_for(operation, payload, result)
      record_failure(release, payload, evidence, result["error"]) if result["error"]
      release.update!(inspection_state: result["error"] ? "failed" : "succeeded")
      { evidence_id: evidence.id, failed: result["error"].present? }
    end

    def self.evidence_for(operation, payload, result)
      operation.release.evidence_items.create!(payload_revision: payload, evidence_key: "inspection-#{operation.id}",
        kind: "inspection", source: "#{payload.format.upcase} · #{payload.original_filename}", captured_at: Time.current,
        input_revision: operation.input_revision, data: result)
    end
    private_class_method :evidence_for

    def self.record_failure(release, payload, evidence, code)
      release.findings.create!(payload_revision: payload, code: "inspection_failure",
        number: release.findings.where(code: "inspection_failure").maximum(:number).to_i + 1,
        severity: "failure", message: I18n.t("ebooks.errors.#{code}", default: I18n.t("ebooks.errors.parser_failed")),
        input_revision: release.input_revision, data: { error: code, evidence_key: evidence.evidence_key })
    end
    private_class_method :record_failure
  end
end
