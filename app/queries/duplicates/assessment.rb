module Duplicates
  class Assessment
    Candidate = Data.define(:evidence, :decision, :review)
    attr_reader :check

    def initialize(release)
      @release = release
      @fingerprint = Inputs.fingerprint(Inputs.call(release: release))
      connection_id = release.provider_assignments.find_by(role: 'publishing')&.provider_connection_id
      @checks = release.duplicate_checks.includes(:duplicate_decisions).order(:id).select { |item| item.query['connection_id'] == connection_id }
      @check = @checks.last
    end

    def current?
      Workspace.current?(@release, @check)
    end

    def candidates
      @candidates ||= @checks.flat_map(&:candidates).index_by { |item| item.fetch('key') }.values.map { |item| candidate(item) }
    end

    def ready?
      current? && search_satisfied? && !blocked?
    end

    def blocked?
      candidates.any? { |item| item.decision != 'false_positive' }
    end

    def confirmed?
      candidates.any? { |item| item.decision == 'confirmed' }
    end

    def manual_exception?
      pair = reviews.reverse.find { |_, review| review.candidate_key == 'manual-search' }
      pair && current? && pair.first.query['fingerprint'] == @fingerprint &&
        pair.first.query['search_id'].present? && pair.first.query['search_id'] == @check.query['search_id']
    end

    private

    def search_satisfied?
      @check.query['status'] == 'complete' || (@check.query['status'] == 'unavailable' && manual_exception?)
    end

    def reviews
      @reviews ||= @checks.flat_map { |item| item.duplicate_decisions.map { |review| [ item, review ] } }
    end

    def decision(review, relevant)
      return 'likely' unless review

      relevant || review.decision == 'confirmed' ? review.decision : 'likely'
    end

    def candidate(evidence)
      pair = reviews.reverse.find { |_, review| review.candidate_key == evidence.fetch('key') }
      review = pair&.last
      relevant = pair && pair.first.query['fingerprint'] == @fingerprint
      decision = decision(review, relevant)
      Candidate.new(evidence: evidence, decision: decision, review: relevant ? review : nil)
    end
  end
end
