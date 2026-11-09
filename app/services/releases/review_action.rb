module Releases
  class ReviewAction
    class UnknownAction < StandardError; end
    class Unavailable < StandardError
      attr_reader :revision

      def initialize(revision)
        @revision = revision
        super(I18n.t('workbench.errors.unavailable_action'))
      end
    end
    KINDS = %w[prepare draft publish].freeze

    def self.call(release_id:, kind:, expected_revision:, changes:)
      raise UnknownAction, I18n.t('workbench.errors.unknown_action') unless KINDS.include?(kind)

      release = Save.call(release_id: release_id, expected_revision: expected_revision, changes: changes)
      raise Unavailable.new(release.input_revision)
    end
  end
end
