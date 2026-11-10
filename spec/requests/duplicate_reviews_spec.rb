require 'rails_helper'

RSpec.describe 'Duplicate search review' do
  let(:release) { reviewed_content_release }

  it 'requires authentication and configured assigned C411 credentials' do
    get release_duplicate_review_path(release)
    expect(response).to redirect_to(new_operator_session_path)
    sign_in_operator
    post release_duplicate_review_path(release), params: { duplicate: { expected_revision: release.input_revision } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('connexion C411')
  end

  it 'shows format and edition evidence without exposing API credentials or download URLs' do
    sign_in_operator
    configure_duplicate_search(release)
    stub_duplicate_search
    search_duplicates(release)
    get release_duplicate_review_path(release)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Synthetic book Test author EPUB', 'Édition numérique de test.', 'Rechercher sur C411')
    expect(response.body).not_to include('synthetic-search-key', '/api/download')
  end
end
