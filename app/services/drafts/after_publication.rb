module Drafts
  class AfterPublication
    class << self
      def call(release_id:)
        release = Release.find(release_id)
        raise Failure.new(:not_published) unless release.publication_state == 'published'
        return false unless release.draft_link
        snapshot = Sync.call(link: release.draft_link)
        !snapshot.remote_deleted
      end

      def observe(release:, snapshot:)
        return unless release.publication_state == 'published' && !snapshot.remote_deleted
        return if release.release_events.where(name: 'draft.leftover').exists?([ "json_extract(data, '$.remote_id') = ?", snapshot.remote_id ])
        Releases::RecordEvent.call(release_id: release.id, name: 'draft.leftover', data: { remote_id: snapshot.remote_id, snapshot_id: snapshot.id })
      end
    end
  end
end
