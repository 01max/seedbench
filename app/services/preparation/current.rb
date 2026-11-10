module Preparation
  class Current
    POLICY = "#{Providers::C411::EbookNaming::VERSION}:local-torrent-v1".freeze

    class << self
      def call(release:, payload: release.payload_revisions.order(number: :desc).first, preparation: release.preparation_revisions.order(number: :desc).first)
        return false unless payload && preparation && release.preparation_state == 'prepared'
        return false unless matching_name?(release, preparation) && preparation.payload_revision_id == payload.id

        matching_payload?(payload, preparation)
      end

      private

      def matching_payload?(payload, preparation)
        payload.locator == preparation.payload_name && preparation.payload_sha256 == payload.sha256 && preparation.payload_size_bytes == payload.size_bytes
      end

      def matching_name?(release, preparation)
        preparation.policy_version == POLICY && release.proposed_name == preparation.release_name
      end
    end
  end
end
