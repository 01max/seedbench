module Duplicates
  class Refresh
    def self.call(operation_id:, attempt_token:)
      raise Failure.new(:transaction_open) if ApplicationRecord.connection.transaction_open?

      new(operation_id, attempt_token).call
    end

    def initialize(operation_id, attempt)
      @operation, @attempt = WorkflowOperation.find(operation_id), attempt
    end

    def call
      @parameters = @operation.release.with_lock { parameters }
      connection = ProviderConnection.find(@parameters.fetch('connection_id'))
      return resume_manual(connection) if @operation.parameters['manual_search_check_id']

      result = Providers::C411::Search.call(connection: connection, queries: @parameters.fetch('queries'))
      check = @operation.release.with_lock { persist(result) }
      raise Failure.new(:review_required) unless Assessment.new(@operation.release).ready?

      check
    end

    private

    def resume_manual(connection)
      @operation.release.with_lock { manual_check! }
      access = Providers::C411.check(connection: connection)
      raise Failure.new(:publication_unavailable) unless access.status == 'passed'

      @operation.release.with_lock do
        raise Failure.new(:stale_review) unless parameters == @parameters

        manual_check!
      end
    rescue Providers::Failure
      raise Failure.new(:publication_unavailable), cause: nil
    end

    def manual_check!
      assessment = Assessment.new(@operation.release)
      check = assessment.check
      valid = check && check.id == @operation.parameters['manual_search_check_id'] && assessment.manual_exception? && assessment.ready?
      raise Failure.new(:stale_review) unless valid && publish_search?(check)

      check
    end

    def publish_search?(check)
      @operation.release.workflow_operations.exists?(id: check.query['search_operation_id'], kind: 'publish', effect: 'remote')
    end

    def parameters
      @operation.reload
      release = @operation.release
      validate_operation!(release)
      connection = release.provider_assignments.find_by(role: 'publishing')&.provider_connection
      raise Failure.new(:connection_required) unless connection && !connection.configuration_incomplete?

      inputs = Inputs.call(release: release)
      { 'inputs' => inputs, 'fingerprint' => Inputs.fingerprint(inputs), 'queries' => Inputs.queries(inputs),
        'connection_id' => connection.id, 'connection_version' => connection.credentials_version }
    end

    def validate_operation!(release)
      valid = @operation.kind == 'publish' && @operation.effect == 'remote' && @operation.state == 'running'
      valid &&= live_attempt?
      raise Failure.new(:explicit_publish_required) unless valid
      raise Releases::RevisionConflict.new(expected_revision: @operation.input_revision, actual_revision: release.input_revision) unless @operation.input_revision == release.input_revision
    end

    def live_attempt?
      @attempt.present? && @operation.attempt_token == @attempt && @operation.lease_expires_at&.future?
    end

    def persist(result)
      raise Failure.new(:stale_review) unless parameters == @parameters

      Record.call(operation: @operation, result: result, parameters: @parameters)
      @operation.release.duplicate_checks.order(:id).last
    end
  end
end
