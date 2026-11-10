module Ai
  class Request
    def self.call(release_id:, expected_revision:, purpose:, scope: {}, initial: false)
      raise Failure.new(:invalid_action) unless %w[assessment prose].include?(purpose)

      new(release_id, expected_revision, purpose, scope, initial).call
    rescue ActiveRecord::RecordNotUnique
      raise Failure.new(:busy), cause: nil
    end

    def initialize(release_id, revision, purpose, scope, initial)
      @release, @revision, @purpose = Release.find(release_id), revision, purpose
      @scope, @initial = scope, initial
    end

    def call
      @release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: @revision, actual_revision: @release.input_revision) unless @release.input_revision == @revision

        @connection = @release.provider_assignments.find_by(role: 'ai')&.provider_connection
        raise Failure.new(:connection_required) unless @connection&.provider == 'openai' && !@connection.configuration_incomplete?

        @pack = EvidencePack.call(release: @release, scope: @scope)
        existing_initial || persist
      end
    end

    private

    def existing_initial
      return unless @initial

      @release.ai_runs.where(purpose: @purpose).where("json_extract(request, '$.initial') = 1 AND json_extract(request, '$.pack.payload_revision_id') = ?", @pack.fetch('payload_revision_id')).first
    end

    def persist
      ensure_idle!

      operation = Workflows::Start.call(release_id: @release.id, kind: "ai_#{@purpose}", request_key: SecureRandom.uuid,
        expected_revision: @revision, parameters: { purpose: @purpose })
      @release.ai_runs.create!(workflow_operation_id: operation.id, provider_connection: @connection, input_revision: @revision,
        purpose: @purpose, model: @connection.options.fetch('model'), prompt_version: Prompts.call(purpose: @purpose).fetch('version'),
        evidence_keys: @pack.fetch('items').pluck('id'), request: snapshot)
    end

    def ensure_idle!
      active = @release.ai_runs.where(purpose: @purpose, status: %w[pending running]).where.not(workflow_operation_id: nil)
      raise Failure.new(:busy) if active.exists?
    end

    def snapshot
      bases = @release.content_revisions.where(id: @release.content_revisions.select('MAX(id)').group(:kind)).pluck(:kind, :id).to_h
      { 'pack' => @pack, 'initial' => @initial, 'connection_version' => @connection.credentials_version,
        'context' => Context.call(release: @release), 'content_bases' => bases }
    end
  end
end
