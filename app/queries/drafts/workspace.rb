module Drafts
  class Workspace
    State = Data.define(:link, :snapshot, :local, :candidates, :configured, :writes, :proposed_ids)

    class << self
      def call(release:, payload_query: '')
        link = release.draft_link
        snapshot = release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last if link
        candidates = PayloadCandidates.call(release: release, query: payload_query)
        State.new(proposed_ids: candidates.proposed_ids, writes: release.draft_writes.includes(:workflow_operation).order(id: :desc).limit(20).to_a, link: link, snapshot: snapshot, local: Content.local(release), candidates: candidates.records,
          configured: configured?(link))
      end

      private

      def configured?(link)
        link.present? && !link.provider_connection.configuration_incomplete?
      end
    end
  end
end
