class EbookCoversController < ApplicationController
  def show
    release = Release.find(params.expect(:release_id))
    path, media_type = Ebooks::CoverAsset.call(release: release, evidence_id: params.expect(:evidence_id), sha256: params.expect(:id))
    response.headers['Cache-Control'] = 'private, no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    send_file path, type: media_type, disposition: 'inline'
  end
end
