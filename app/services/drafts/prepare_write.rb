module Drafts
  class PrepareWrite
    def self.call(write:)
      release = Guard.call(write)
      Sync.call(link: release.draft_link) if release.draft_link
      release = Guard.call(write)
      if write.request['payload_id']
        Preparation::Validate.call(release: release)
        host(write)
        ::Content::ReviewedAction.call(operation_id: write.workflow_operation_id, attempt_token: write.workflow_operation.attempt_token)
      else
        unlinked(write, release)
      end
    end

    class << self
      private

      def host(write)
        Covers::Host.call(operation_id: write.workflow_operation_id, attempt_token: write.workflow_operation.attempt_token)
      end

      def unlinked(write, release)
        snapshot = release.remote_snapshots.where(kind: 'draft').order(:id).last!
        before = images(snapshot.base_content['description'])
        after = images(write.request.fetch('content').fetch('description'))
        selected = release.cover_revisions.exists?
        hosting = host(write) if selected
        verify_images!(after - before, hosting, after)
      end

      def verify_images!(changed, hosting, images)
        raise Covers::Failure.new(:review_required_for_write) if hosting && images.exclude?(hosting.direct_url)
        raise Failure.new(:cover_required) unless changed.empty? || (hosting && changed == [ hosting.direct_url ])
      end

      def images(body)
        body.to_s.scan(/\[img\](.*?)\[\/img\]/im).flatten.map(&:strip).uniq
      end
    end
  end
end
