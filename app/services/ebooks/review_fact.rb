module Ebooks
  class ReviewFact
    class InvalidCandidate < StandardError; end
    FIELDS = %w[title author isbn edition language].freeze

    class << self
      def call(release_id:, evidence_id:, candidate_index:, expected_revision:)
        release = Release.find(release_id)
        release.with_lock do
          raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

          evidence = release.evidence_items.find(evidence_id)
          candidate = candidate_for(release, evidence, candidate_index)
          accept(release, evidence, candidate)
        end
      end

      private

      def candidate_for(release, evidence, index)
        candidates = evidence.data.fetch('candidates', [])
        candidate = candidates[index] if index.is_a?(Integer) && index >= 0
        current = release.payload_revisions.order(number: :desc).pick(:id)
        validate_candidate!(candidate, current == evidence.payload_revision_id)
        raise InvalidCandidate, I18n.t('ebooks.review.invalid_isbn') if candidate['field'] == 'isbn' && !Isbn.valid?(candidate['value'])

        candidate
      end

      def validate_candidate!(candidate, current)
        raise InvalidCandidate, I18n.t('ebooks.review.invalid_candidate') unless current && candidate && FIELDS.include?(candidate['field'])
      end

      def accept(release, evidence, candidate)
        revision = release.input_revision
        field, value = candidate.values_at('field', 'value')
        Releases::Save.call(release_id: release.id, expected_revision: revision, changes: { field => value })
        release.reload
        fact = release.reviewed_facts.where(field: field).order(:number).last
        fact = append_unchanged(release, evidence, field, value) if release.input_revision == revision
        release.fact_evidence_links.create!(reviewed_fact: fact, evidence_item: evidence)
        Releases::RecordEvent.call(release_id: release.id, name: 'fact.reviewed', actor: 'operator', data: { fact_id: fact.id, evidence_id: evidence.id })
        Findings.call(release: release, payload: evidence.payload_revision)
        release
      end

      def append_unchanged(release, evidence, field, value)
        release.update!(input_revision: release.input_revision + 1)
        release.reviewed_facts.create!(payload_revision_id: evidence.payload_revision_id, field: field, value: value,
          number: release.reviewed_facts.where(field: field).maximum(:number).to_i + 1, actor: 'operator', reviewed_at: Time.current)
      end
    end
  end
end
