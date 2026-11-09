module Content
  class Accept
    class StaleProposal < StandardError; end

    def self.call(release_id:, proposal_id:, expected_revision:)
      release = Release.find(release_id)
      release.with_lock do
        proposal = release.content_proposals.find(proposal_id)
        return release if accepted?(release, proposal)
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        verify!(release, proposal)
        apply(release, proposal)
        release
      end
    end

    class << self
      private

      def accepted?(release, proposal)
        release.content_revisions.exists?([ "json_extract(dependencies, '$.proposal_id') = ?", proposal.id ])
      end

      def verify!(release, proposal)
        proposal.bodies.each_key do |kind|
          current = release.content_revisions.where(kind: kind).order(:number).last
          dependency = Capture.call(release: release, kind: kind)
          valid = current&.id == proposal.bases[kind] && dependency['fingerprint'] == proposal.dependencies.dig(kind, 'fingerprint') &&
            proposal.dependencies.dig(kind, 'policy_version') == Providers::C411::EbookContent::VERSION
          raise StaleProposal, I18n.t('content.errors.stale_proposal') unless valid
        end
      end

      def append(release, proposal, inputs, kind, body)
        release.content_revisions.create!(kind: kind, body: body, number: release.content_revisions.where(kind: kind).maximum(:number).to_i + 1,
          origin: proposal.kind == 'cover' ? 'human' : 'generated', input_revision: release.input_revision + 1,
          payload_revision: inputs.payload, preparation_revision: inputs.preparation, cover_revision: inputs.cover,
          dependencies: proposal.dependencies.fetch(kind).merge('proposal_id' => proposal.id))
      end

      def apply(release, proposal)
        inputs = Inputs.new(release)
        proposal.bodies.each do |kind, body|
          append(release, proposal, inputs, kind, body)
        end
        release.update!(input_revision: release.input_revision + 1)
        Releases::RecordEvent.call(release_id: release.id, name: 'content.accepted', actor: 'operator', data: { proposal_id: proposal.id, kinds: proposal.bodies.keys })
      end
    end
  end
end
