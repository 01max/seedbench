module Content
  class CoverPatch
    class Unavailable < StandardError; end

    def self.call(release_id:, expected_revision:)
      release = Release.find(release_id)
      release.with_lock do
        raise Releases::RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision

        persist(release)
      end
    end

    class << self
      private

      def persist(release)
        inputs = Inputs.new(release)
        current = inputs.contents['bbcode']
        fields = current && Providers::C411::EbookContent.fields(body: current.body)
        raise Unavailable, I18n.t('content.errors.cover_patch') unless fields && inputs.hosting

        record(release, inputs, current, fields)
      end

      def record(release, inputs, current, fields)
        proposal = release.content_proposals.create!(kind: 'cover', input_revision: release.input_revision,
          bodies: { 'bbcode' => replace(current.body, fields['cover'], inputs.hosting.direct_url) },
          dependencies: { 'bbcode' => Capture.call(release: release, kind: 'bbcode') }, bases: { 'bbcode' => current.id })
        Releases::RecordEvent.call(release_id: release.id, name: 'content.proposed', actor: 'operator', data: { proposal_id: proposal.id, kinds: [ 'bbcode' ] })
        proposal
      end

      def replace(body, previous, url)
        prefix = "[center][img]#{previous}[/img][/center]"
        body.sub(/\A#{Regexp.escape(prefix)}/, "[center][img]#{url}[/img][/center]")
      end
    end
  end
end
