module Workflows
  class RecordOutcome
    class Conflict < StandardError; end

    def self.call(operation_id:, attempt_token:, phase:, reference:)
      Releases::EventMetadata.validate!(reference)
      raise ArgumentError, "Invalid operation phase." unless phase.is_a?(String) && phase.match?(/\A[a-z][a-z0-9_]{0,79}\z/)

      operation = WorkflowOperation.find(operation_id)
      operation.with_lock do
        return unless %w[running outcome_unknown stale].include?(operation.state) && operation.attempt_token == attempt_token
        raise ArgumentError, "Local operations have no external outcome journal." if operation.effect == "local"

        merge_outcome(operation, phase, JSON.parse(JSON.generate(reference)))
      end
    end

    def self.merge_outcome(operation, phase, reference)
      previous = operation.external_reference
      raise Conflict, "A recorded external identity cannot be replaced." unless
        (previous.keys & reference.keys).all? { |key| previous.fetch(key) == reference.fetch(key) }
      return operation if previous == previous.merge(reference) && operation.phase == phase

      operation.update!(phase: phase, external_reference: previous.merge(reference))
      Releases::RecordEvent.call(release_id: operation.release_id, name: "operation.outcome_recorded", data: { operation_id: operation.id, phase: phase })
      operation
    end
    private_class_method :merge_outcome
  end
end
