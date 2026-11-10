module Ai
  class AcceptFact
    def self.call(release_id:, run_id:, candidate_index:, expected_revision:)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        run = release.ai_runs.find(run_id)
        candidate = candidate_for(run, release, candidate_index)
        evidence = evidence_for(run, release, candidate, candidate_index)
        Ebooks::ReviewFact.call(release_id: release.id, evidence_id: evidence.id, candidate_index: 0, expected_revision: expected_revision)
      end
    end

    class << self
      private

      def candidate_for(run, release, index)
        raise Failure.new(:stale_output) unless run.purpose == 'assessment' && Relevance.current?(run: run, context: Context.call(release: release))

        output = Output.call(purpose: run.purpose, output: run.result.fetch('output'), pack: run.request.fetch('pack'))
        candidate = output.fetch('candidates')[index] if index.is_a?(Integer) && index >= 0
        raise Failure.new(:invalid_action) unless candidate

        candidate
      end

      def evidence_data(run, candidate)
        source = candidate.merge('source' => I18n.t('ai.fact_source', number: run.id))
        { ai_run_id: run.id, candidates: Ebooks::Candidates.call(report: { 'metadata' => [ source ] }),
          citations: run.request.fetch('pack').fetch('items').select { |item| candidate.fetch('evidence_ids').include?(item['id']) } }
      end

      def evidence_for(run, release, candidate, index)
        release.evidence_items.find_by(evidence_key: "ai-#{run.id}-#{index}") ||
          release.evidence_items.create!(payload_revision_id: run.request.dig('pack', 'payload_revision_id'), kind: 'ai_assessment',
            evidence_key: "ai-#{run.id}-#{index}", source: I18n.t('ai.fact_source', number: run.id), captured_at: Time.current,
            input_revision: run.input_revision, data: evidence_data(run, candidate))
      end
    end
  end
end
