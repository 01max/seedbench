module Preparation
  # Invalidates prepared output when the operator changes a proposed name that can still be edited.
  class Invalidate
    def self.call(release:, changes:)
      return unless changes.key?('proposed_name')
      raise Failure.new(:published_locked) unless %w[unpublished failed].include?(release.publication_state) && release.seeding_state == 'not_started'

      release.update!(preparation_state: 'stale') if release.preparation_state == 'prepared'
    end
  end
end
