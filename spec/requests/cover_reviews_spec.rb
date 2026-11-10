require 'rails_helper'

RSpec.describe 'Local cover review' do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }

  it 'selects and displays a local raster without a provider write' do
    sign_in_operator
    post release_cover_review_path(release), params: { cover: { kind: 'select', source: 'manual', expected_revision: 0,
      image: ebook_upload('cover.png', bytes: cover_bytes), review: { edition_match: '1', quality_reviewed: '1' } } }
    expect(response).to have_http_status(:ok)
    cover = release.cover_revisions.sole
    get release_selected_cover_path(release, cover_id: cover.id)
    expect(response.media_type).to eq('image/png')
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
    expect(release.cover_hostings).to be_empty
  end

  it 'requires authentication and scopes selected images to the release' do
    cover = choose_manual_cover(release)
    get release_selected_cover_path(release, cover_id: cover.id)
    expect(response).to redirect_to(new_operator_session_path)
    sign_in_operator
    other = staged_preparation_release
    get release_selected_cover_path(other, cover_id: cover.id)
    expect(response).to have_http_status(:not_found)
  end
end
