module Ebooks
  class Record
    class << self
      def call(operation:, result:)
        result['candidates'] = Candidates.call(report: result)
        release = operation.release
        payload = release.payload_revisions.find(operation.parameters.fetch('payload_revision_id'))
        evidence = evidence_for(operation, payload, result)
        Findings.call(release: release, payload: payload)
        release.update!(inspection_state: result['error'] ? 'failed' : 'succeeded')
        Ai::Initial.call(release: release) unless result['error']
        { evidence_id: evidence.id, failed: result['error'].present? }
      end

      private

      def evidence_for(operation, payload, result)
        operation.release.evidence_items.create!(payload_revision: payload, evidence_key: "inspection-#{operation.id}",
          kind: 'inspection', source: "#{payload.format.upcase} · #{payload.original_filename}", captured_at: Time.current,
          input_revision: operation.input_revision, data: result)
      end
    end
  end
end
