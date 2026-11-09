class ContentPreviewsController < ApplicationController
  def create
    release = Release.find(params.expect(:release_id))
    source = params.expect(preview: [ :bbcode ]).fetch(:bbcode, '')
    raise ActionController::BadRequest unless source.is_a?(String)

    result = Content::Render.call(source: source, cover_url: Content::Inputs.new(release).hosting&.direct_url)
    render json: { html: result.html, errors: result.errors.map { |code| I18n.t("content.errors.#{code}") } }
  end
end
