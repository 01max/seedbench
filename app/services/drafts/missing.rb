module Drafts
  class Missing
    class << self
      def call(link:, expected_snapshot_id: nil)
        release = link.release
        release.with_lock do
          raise Failure.new(:invalid_link) unless DraftLink.exists?(id: link.id, release_id: release.id)
          previous = release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last!
          raise Failure.new(:observation_changed) if expected_snapshot_id && previous.id != expected_snapshot_id
          return previous if previous.remote_deleted
          record(release, link, previous)
        end
      end

      private

      def record(release, link, previous)
        snapshot = release.remote_snapshots.create!(provider_connection: link.provider_connection, kind: 'draft', remote_id: link.remote_id,
          local_revision: release.input_revision, base_content: previous.base_content, remote_content: previous.remote_content,
          remote_deleted: true, observed_at: Time.current)
        release.update!(draft_state: 'missing')
        Releases::RecordEvent.call(release_id: release.id, name: 'draft.missing', data: { snapshot_id: snapshot.id, remote_id: link.remote_id })
        snapshot
      end
    end
  end
end
