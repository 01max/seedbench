module SyntheticWorkflow
  class Compute
    def self.call(operation:)
      { "label" => "Synthetic evidence", "input_revision" => operation.input_revision }
    end
  end

  class Apply
    def self.call(operation:, result:)
      evidence = EvidenceItem.create!(release_id: operation.release_id,
        payload_revision_id: operation.parameters.fetch("payload_revision_id"), evidence_key: "workflow-#{operation.id}",
        kind: "metadata", source: "synthetic workflow", captured_at: Time.current,
        input_revision: operation.input_revision, data: result)
      { "evidence_id" => evidence.id }
    end
  end
end
