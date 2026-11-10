module Duplicates
  class Review
    class << self
      def call(release_id:, expected_revision:, check_id:, candidate_key:, decision:, reason: '')
        raise Failure.new(:invalid_decision) unless %w[likely confirmed false_positive].include?(decision)

        new(release_id, expected_revision, check_id, candidate_key, decision, reason).call
      end

      def manual_exception(release_id:, expected_revision:, check_id:, reason:)
        new(release_id, expected_revision, check_id, 'manual-search', 'manual_exception', reason).manual_exception
      end
    end

    def initialize(release_id, revision, check_id, key, decision, reason)
      @release, @revision, @check_id = Release.find(release_id), revision, check_id.to_i
      @key, @decision, @reason = key, decision, reason.to_s.strip
    end

    def call
      @release.with_lock do
        validate!
        persist
      end
    end

    def manual_exception
      @release.with_lock { validate! }
      connection = @release.provider_assignments.find_by!(role: 'publishing').provider_connection
      raise Failure.new(:publication_unavailable) unless connection && !connection.configuration_incomplete?

      raise Failure.new(:publication_unavailable) unless available?(connection)

      call
    rescue Providers::Failure
      raise Failure.new(:publication_unavailable), cause: nil
    end

    private

    def available?(connection)
      version = connection.credentials_version
      result = Providers::C411.check(connection: connection)
      result.status == 'passed' && connection.reload.credentials_version == version
    end

    def validate!
      raise Releases::RevisionConflict.new(expected_revision: @revision, actual_revision: @release.input_revision) unless @release.input_revision == @revision

      @assessment = Assessment.new(@release)
      raise Failure.new(:stale_review) unless @assessment.current? && @assessment.check.id == @check_id
      validate_reason!
      raise Failure.new(:invalid_decision) unless valid_target?
    end

    def validate_reason!
      raise Failure.new(:reason_required) unless @reason.length <= 2000 && (reason_optional? || @reason.length >= 20)
    end

    def reason_optional?
      %w[likely confirmed].include?(@decision)
    end

    def valid_target?
      return @assessment.check.query['status'] == 'unavailable' if @decision == 'manual_exception'

      @assessment.candidates.any? { |item| item.evidence['key'] == @key }
    end

    def record_event(check, review)
      Releases::RecordEvent.call(release_id: @release.id, name: 'duplicates.reviewed', actor: 'operator',
        data: { check_id: check.id, review_id: review.id, decision: @decision })
    end

    def persist
      previous = @assessment.check
      check = @release.duplicate_checks.create!(input_revision: @revision + 1, searched_at: previous.searched_at,
        query: previous.query.merge('review_of_id' => previous.id), candidates: @assessment.candidates.map(&:evidence))
      review = check.duplicate_decisions.create!(release_id: @release.id, candidate_key: @key, decision: @decision,
        reason: @reason.presence, actor: 'operator', reviewed_at: Time.current)
      @release.update!(input_revision: @revision + 1)
      record_event(check, review)
      review
    end
  end
end
