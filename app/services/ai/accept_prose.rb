module Ai
  class AcceptProse
    def self.call(release_id:, run_id:, field:, expected_revision:)
      new(release_id, run_id, field, expected_revision).call
    end

    def initialize(release_id, run_id, field, revision)
      @release, @field, @revision = Release.find(release_id), field, revision
      @run = @release.ai_runs.find(run_id)
    end

    def call
      @release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: @revision, actual_revision: @release.input_revision) unless @release.input_revision == @revision

        current = @release.content_revisions.where(kind: @field).order(:number).last
        return @release if current&.dependencies&.fetch('ai_run_id', nil) == @run.id

        validate!(current)
        persist
        @release
      end
    end

    private

    def validate!(current)
      allowed = Relevance.prose?(run: @run, context: Context.call(release: @release), content_ids: { @field => current&.id }, field: @field)
      raise Failure.new(:stale_output) unless allowed

      Output.call(purpose: @run.purpose, output: @run.result.fetch('output'), pack: @run.request.fetch('pack'))
    end

    def persist
      @release.content_revisions.create!(payload_revision_id: @run.request.dig('pack', 'payload_revision_id'), kind: @field,
        body: @run.result.fetch('output').fetch(@field), number: @release.content_revisions.where(kind: @field).maximum(:number).to_i + 1,
        origin: 'ai', input_revision: @revision + 1, dependencies: { ai_run_id: @run.id, evidence_keys: @run.evidence_keys })
      @release.update!(input_revision: @revision + 1)
      Releases::RecordEvent.call(release_id: @release.id, name: 'ai.prose_accepted', actor: 'operator', data: { ai_run_id: @run.id, field: @field })
    end
  end
end
