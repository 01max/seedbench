module Ai
  class Record
    class << self
      def call(operation:, result:)
        run = operation.release.ai_runs.find_by!(workflow_operation_id: operation.id)
        return { ai_run_id: run.id, status: run.status } unless %w[pending running].include?(run.status)

        validate_output!(run, result)
        status = result.fetch('status')
        status = 'stale' if result['output'] && stale?(run)
        persist(run, result, status)
      end

      private

      def persist(run, result, status)
        run.update!(status: status, result: result.except('status', 'error_code'), error_code: result['error_code'])
        Releases::RecordEvent.call(release_id: run.release_id, name: 'ai.completed', data: { ai_run_id: run.id, status: run.status })
        { ai_run_id: run.id, status: run.status }
      end

      def validate_output!(run, result)
        return unless result['output']

        Output.call(purpose: run.purpose, output: result['output'], pack: run.request.fetch('pack'))
      end

      def stale?(run)
        run.input_revision != run.release.input_revision || run.provider_connection.credentials_version != run.request.fetch('connection_version')
      end
    end
  end
end
