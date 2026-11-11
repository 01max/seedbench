module Preparation
  class Validate
    class << self
      def call(release:)
        raise Failure.new(:stale) unless Current.call(release: release)

        preparation = release.preparation_revisions.order(number: :desc).first!
        payload = preparation.payload_revision
        paths = Paths.new
        path = payload_path(release: release, preparation: preparation, paths: paths)
        info_hash = Torrents::Verify.call(torrent: paths.path(preparation.torrent_locator, kind: :state), payload_path: path,
          payload: payload, name: preparation.payload_name)
        raise Failure.new(:invalid_torrent) unless info_hash == preparation.torrent_info_hash

        preparation
      end

      def payload_path(release:, preparation:, paths: Paths.new)
        verify_root!(release, preparation, paths)
        paths.path(preparation.payload_revision.locator)
      end

      private

      def verify_root!(release, preparation, paths)
        operation = release.workflow_operations.where(kind: 'preparation', state: 'succeeded').find { |candidate| candidate.result['preparation_id'] == preparation.id }
        move = operation&.payload_moves&.find_by(payload_revision_id: preparation.payload_revision_id, destination_locator: preparation.payload_name, state: 'completed')
        root = paths.root.stat
        raise Failure.new(:mapping_changed) unless move && [ root.dev, root.ino ] == [ move.root_device, move.root_inode ]
      end
    end
  end
end
