module Workflows
  class Start
    class IdempotencyConflict < StandardError; end
    class UnresolvedEffect < StandardError; end

    def self.call(release_id:, kind:, request_key:, expected_revision:, parameters: {})
      definition = Definitions.fetch(kind)
      Releases::EventMetadata.validate!(parameters)
      parameters = JSON.parse(JSON.generate(parameters))
      release = Release.find(release_id)
      release.with_lock do
        persist(release, kind: kind, request_key: request_key, expected_revision: expected_revision,
          parameters: parameters, effect: definition.effect)
      end
    end

    def self.persist(release, kind:, request_key:, expected_revision:, parameters:, effect:)
      existing = release.workflow_operations.find_by(request_key: request_key)
      return existing_request(existing, kind, expected_revision, parameters) if existing
      raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision
      raise UnresolvedEffect, "Reconcile the existing non-local operation before starting another." if unresolved_effect?(release, kind)

      operation = release.workflow_operations.create!(kind: kind, request_key: request_key, input_revision: expected_revision, parameters: parameters, effect: effect)
      operation.create_dispatch_intent!(release: release)
      Releases::RecordEvent.call(release_id: release.id, name: "operation.requested", data: { operation_id: operation.id, kind: kind })
      ActiveRecord.after_all_transactions_commit { Dispatch.call(operation_id: operation.id) }
      operation
    end
    private_class_method :persist

    def self.unresolved_effect?(release, kind)
      release.workflow_operations.where(kind: kind).where.not(effect: "local")
        .where("state IN ('pending', 'running', 'outcome_unknown') OR (state = 'stale' AND attempts > 0)").exists?
    end
    private_class_method :unresolved_effect?

    def self.existing_request(operation, kind, revision, parameters)
      raise IdempotencyConflict, "The request key already belongs to different inputs." unless
        operation.kind == kind && operation.input_revision == revision && operation.parameters == parameters

      operation
    end
    private_class_method :existing_request
  end
end
