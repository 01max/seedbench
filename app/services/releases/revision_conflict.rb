module Releases
  class RevisionConflict < StandardError
    attr_reader :expected_revision, :actual_revision

    def initialize(expected_revision:, actual_revision:)
      @expected_revision = expected_revision
      @actual_revision = actual_revision
      super(I18n.t('messages.releases.revision_conflict.release_inputs_changed_reload_the_current'))
    end
  end
end
