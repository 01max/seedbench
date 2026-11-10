module Drafts
  class Observe
    class << self
      def call(link:, content:, remote_revision:, expected_snapshot_id: nil)
        release = link.release
        release.with_lock do
          raise Failure.new(:invalid_link) unless DraftLink.exists?(id: link.id, release_id: release.id)
          previous = release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last!
          raise Failure.new(:observation_changed) if expected_snapshot_id && previous.id != expected_snapshot_id
          observe(release, link, previous.base_content, content, remote_revision)
        end
      end

      private

      def observe(release, link, base, content, remote_revision)
        local = Content.local(release)
        conflict = conflicted?(release, local, base, content)
        adopt_remote(release, local, base, content) unless conflict
        base = content if !conflict && Content.local(release.reload) == content
        record(release, link, content, base, remote_revision, conflict)
      end

      def conflicted?(release, local, base, remote)
        return local != remote if release.publication_state == 'published'
        local != base && remote != base && local != remote
      end

      def adopt_remote(release, local, base, content)
        Content.adopt(release, content) if local == base && local != content
      end

      def record(release, link, content, base, revision, conflicted)
        snapshot = release.remote_snapshots.create!(provider_connection: link.provider_connection, kind: 'draft', remote_id: link.remote_id,
          local_revision: release.input_revision, remote_revision: revision.to_s.first(100), base_content: base, remote_content: content, observed_at: Time.current)
        state = conflicted ? 'conflicted' : 'synced'
        changed = release.draft_state != state
        release.update!(draft_state: state) if changed
        Releases::RecordEvent.call(release_id: release.id, name: 'draft.observed', data: { snapshot_id: snapshot.id, conflicted: conflicted })
        snapshot
      end
    end
  end
end
