module SyntheticWorkflow
  class Compute
    class << self
      def call(operation:)
        pause_for_verification(operation) if operation.parameters['pause_compute']
        { 'label' => 'Synthetic evidence', 'input_revision' => operation.input_revision }
      end

      private

      def pause_for_verification(operation)
        scratch = Rails.application.config.x.storage.fetch(:scratch)
        File.write(scratch.join("workflow-started-#{operation.id}"), operation.attempt_token)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
        until scratch.join("workflow-continue-#{operation.id}").exist?
          raise 'Synthetic compute wait expired' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep 0.05
        end
      end
    end
  end

  class Apply
    def self.call(operation:, result:)
      evidence = EvidenceItem.create!(release_id: operation.release_id,
        payload_revision_id: operation.parameters.fetch('payload_revision_id'), evidence_key: "workflow-#{operation.id}",
        kind: 'metadata', source: 'synthetic workflow', captured_at: Time.current,
        input_revision: operation.input_revision, data: result)
      { 'evidence_id' => evidence.id }
    end
  end
end
