module Preparation
  class Validate
    def self.call(release:)
      raise Failure.new(:stale) unless Current.call(release: release)

      payload = release.payload_revisions.order(number: :desc).first!
      preparation = release.preparation_revisions.order(number: :desc).first!
      paths = Paths.new
      info_hash = Torrents::Verify.call(torrent: paths.path(preparation.torrent_locator, kind: :state), payload_path: paths.path(payload.locator),
        payload: payload, name: preparation.payload_name)
      raise Failure.new(:invalid_torrent) unless info_hash == preparation.torrent_info_hash

      preparation
    end
  end
end
