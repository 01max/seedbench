module Content
  class Propose
    class InvalidKind < StandardError; end

    def self.call(release_id:, expected_revision:, kind:)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision
        raise InvalidKind, I18n.t('content.errors.invalid_action') unless %w[bbcode nfo].include?(kind)

        persist(release, kind)
      end
    end
    class << self
      private

      def persist(release, kind)
        draft = Generate.call(release: release)
        base = release.content_revisions.where(kind: kind).order(:number).last
        proposal = release.content_proposals.create!(kind: 'replacement', input_revision: release.input_revision,
          bodies: draft.bodies.slice(kind), dependencies: draft.dependencies.slice(kind), bases: { kind => base&.id })
        Releases::RecordEvent.call(release_id: release.id, name: 'content.proposed', actor: 'operator', data: { proposal_id: proposal.id, kinds: [ kind ] })
        proposal
      end
    end
  end
end
