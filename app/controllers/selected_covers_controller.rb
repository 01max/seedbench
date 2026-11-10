class SelectedCoversController < ApplicationController
  def show
    release = Release.find(params.expect(:release_id))
    cover = release.cover_revisions.find(params.expect(:cover_id))
    bytes = Covers::Asset.read(locator: cover.source_locator, sha256: cover.edition_evidence['sha256'])
    secure_headers
    send_data bytes, type: cover.edition_evidence.fetch('media_type'), disposition: 'inline'
  rescue Covers::Failure
    head :not_found
  end

  private

  def secure_headers
    response.headers['Cache-Control'] = 'private, no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
  end
end
