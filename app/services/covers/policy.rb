require 'digest'

module Covers
  class Policy
    VERSION = 'cover-verification-v1'.freeze
    FACTS = %w[title author isbn isbn_kind edition publisher publication_year language].freeze

    class << self
      def current?(release:, cover:)
        return false unless cover && reviewed?(cover) && usable_dimensions?(cover)
        return false unless cover.payload_revision_id == release.payload_revisions.order(number: :desc).pick(:id)

        cover.edition_evidence['reviewed_facts'] == facts(release)
      end

      def facts(release)
        Releases::EditorValues.call(release: release).slice(*FACTS).transform_values(&:strip)
      end

      def fingerprint(cover)
        Digest::SHA256.hexdigest(JSON.generate(cover.edition_evidence.fetch('reviewed_facts', {}).sort.to_h))
      end

      def verified?(hosting, cover)
        return false unless hosting && hosting.cover_revision_id == cover.id && raster_url?(hosting)

        proof = hosting.verification
        proof['policy'] == VERSION && proof['source_sha256'] == cover.edition_evidence['sha256'] && proof['edition_fingerprint'] == fingerprint(cover)
      end

      private

      def reviewed?(cover)
        data = cover.edition_evidence
        data['edition_match'] == true && data['quality_reviewed'] == true && data['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
      end

      def usable_dimensions?(cover)
        return false unless cover.width.to_i.positive? && cover.height.to_i.positive?
        return true if cover.height >= cover.width

        [ true, '1' ].include?(cover.edition_evidence['comparable_detail']) && cover.edition_evidence['note'].to_s.strip.length >= 20
      end

      def raster_url?(hosting)
        %w[image/jpeg image/png image/webp].include?(hosting.media_type) && Providers::C411::EbookContent.safe_url?(hosting.direct_url) &&
          hosting.width.positive? && hosting.height.positive?
      end
    end
  end
end
