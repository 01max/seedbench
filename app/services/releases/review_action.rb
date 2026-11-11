module Releases
  class ReviewAction
    class UnknownAction < StandardError; end
    KINDS = %w[suggest_name prepare draft publish].freeze

    def self.call(release_id:, kind:, expected_revision:, changes:)
      raise UnknownAction, I18n.t('workbench.errors.unknown_action') unless KINDS.include?(kind)

      release = Save.call(release_id: release_id, expected_revision: expected_revision, changes: changes)
      return Preparation::SuggestName.call(release: release) if kind == 'suggest_name'
      return Preparation::Request.call(release_id: release.id, expected_revision: release.input_revision) if kind == 'prepare'

      return Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision) if kind == 'draft'

      Publications::Request.call(release_id: release.id, expected_revision: release.input_revision)
    end
  end
end
