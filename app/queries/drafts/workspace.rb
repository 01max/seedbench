module Drafts
  class Workspace
    State = Data.define(:link, :snapshot, :local, :candidates, :configured, :writes)

    class << self
      def call(release:)
        link = release.draft_link
        snapshot = release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last if link
        connection = release.provider_assignments.find_by(role: 'publishing')&.provider_connection
        State.new(writes: release.draft_writes.includes(:workflow_operation).order(id: :desc).limit(20).to_a, link: link, snapshot: snapshot, local: Content.local(release), candidates: candidates,
          configured: connection && !connection.configuration_incomplete?)
      end

      private

      def candidates
        Release.where.not(id: DraftLink.select(:release_id)).where(id: PayloadRevision.select(:release_id))
          .where(publication_state: 'unpublished').order(:id).limit(100).to_a
      end
    end
  end
end
