module Ai
  class Compute
    def self.call(operation:)
      new(operation).call
    end

    def initialize(operation)
      @operation = operation
      @run = operation.release.ai_runs.find_by!(workflow_operation_id: operation.id)
    end

    def call
      activate!
      generate

    rescue Providers::Failure => error
      { 'status' => 'failed', 'error_code' => error.code }
    rescue Failure => error
      { 'status' => 'unusable', 'error_code' => error.code }
    rescue StandardError
      record_failure
      raise
    end

    private

    def generate
      connection = @run.provider_connection
      raise Failure.new(:connection_changed) unless connection.credentials_version == @run.request.fetch('connection_version')
      raise Failure.new(:prompt_changed) unless @run.prompt_version == Prompts.call(purpose: @run.purpose).fetch('version')

      result = Providers::Openai::Generate.call(connection: connection, model: @run.model, purpose: @run.purpose, pack: @run.request.fetch('pack'))
      result.merge('status' => 'succeeded')
    end

    def record_failure
      @run.update!(status: 'failed', error_code: 'execution_failed') if %w[pending running].include?(@run.reload.status)
    end

    def activate!
      @run.with_lock do
        raise Failure.new(:interrupted) unless @run.status == 'pending'

        @run.update!(status: 'running')
      end
    end
  end
end
