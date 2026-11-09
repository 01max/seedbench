module Preparation
  class Build
    def self.call(operation:)
      Reconcile.call(operation: operation)
      Guard.call(operation: operation, attempt: operation.attempt_token)
      payload = operation.release.payload_revisions.find(operation.parameters.fetch('payload_revision_id'))
      names = Providers::C411::EbookNaming.from_release(name: operation.parameters.fetch('release_name'), format: payload.format)
      Move.call(operation: operation, names: names)
      torrent = Torrent.call(operation: operation, names: names)
      { 'torrent_locator' => torrent.locator, 'torrent_info_hash' => torrent.info_hash, 'payload_name' => names.payload }
    rescue Failure => error
      { 'error_code' => error.code }
    rescue Releases::RevisionConflict
      { 'error_code' => 'input_changed' }
    rescue SystemCallError, IOError
      { 'error_code' => 'storage_unavailable' }
    end
  end
end
