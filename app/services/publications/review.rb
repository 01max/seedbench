module Publications
  class Review
    class << self
      def refresh(operation)
        Duplicates::Refresh.call(operation_id: operation.id, attempt_token: operation.attempt_token)
      end

      def manual_search_check_id(release)
        assessment = Duplicates::Assessment.new(release)
        check = assessment.check
        return unless check && assessment.manual_exception?
        return unless release.workflow_operations.exists?(id: check.query['search_operation_id'], kind: 'publish', effect: 'remote')

        check.id
      end

      def verify!(release:, refreshed_check:)
        assessment = Duplicates::Assessment.new(release)
        raise Failure.new(:duplicates) unless assessment.ready? && assessment.check.id == refreshed_check.id
      end
    end
  end
end
