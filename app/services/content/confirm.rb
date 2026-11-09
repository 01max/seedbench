module Content
  class Confirm
    class InvalidContent < StandardError; end

    def self.call(release_id:, expected_revision:, kind:)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision
        raise Propose::InvalidKind, I18n.t('content.errors.invalid_action') unless %w[bbcode nfo].include?(kind)

        state = Status.call(release: release).kinds.fetch(kind)
        raise InvalidContent, I18n.t('content.errors.invalid_content') unless state[:revision] && state[:issues].empty?

        persist(release, kind, state.fetch(:revision))
      end
    end
    class << self
      private

      def persist(release, kind, current)
        inputs = Inputs.new(release)
        release.content_revisions.create!(kind: kind, body: current.body, number: current.number + 1, origin: 'human',
          input_revision: release.input_revision + 1, payload_revision: inputs.payload,
          preparation_revision: inputs.preparation, cover_revision: inputs.cover,
          dependencies: Capture.call(release: release, kind: kind))
        release.update!(input_revision: release.input_revision + 1)
        Releases::RecordEvent.call(release_id: release.id, name: 'content.confirmed', actor: 'operator', data: { kinds: [ kind ] })
        release
      end
    end
  end
end
