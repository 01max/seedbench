module Preparation
  class Observe
    def self.call(release:)
      return unless release.preparation_state == 'prepared'

      preparation = release.preparation_revisions.order(number: :desc).first
      Validate.call(release: release)
    rescue Failure, SystemCallError, IOError
      release.with_lock do
        if release.preparation_state == 'prepared' && release.preparation_revisions.order(number: :desc).pick(:id) == preparation&.id
          release.update!(preparation_state: 'stale')
          Releases::RecordEvent.call(release_id: release.id, name: 'preparation.invalidated')
        end
      end
    end
  end
end
