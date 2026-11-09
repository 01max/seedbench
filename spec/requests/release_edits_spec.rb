require 'rails_helper'

RSpec.describe 'Local release edits' do
  let(:release) { Releases::Create.call(title: 'Synthetic') }

  it 'requires authentication for local writes' do
    patch release_path(release), params: { edit: { expected_revision: 0, title: 'Forged' } }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(release.reload.title).to eq('Synthetic')
  end

  it 'saves the submitted full text and returns the new revision' do
    sign_in_operator
    patch release_path(release), params: { edit: { expected_revision: 0, bbcode: '[b]Saved[/b]', nfo: 'Full NFO' } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('revision' => 1)
    expect(release.content_revisions.where(kind: 'nfo').sole.body).to eq('Full NFO')
  end

  it 'returns both a conflict and the saved text without applying an older form' do
    sign_in_operator
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { title: 'Newer title' })
    patch release_path(release), params: { edit: { expected_revision: 0, title: 'Older title' } }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body).to include('current_revision' => 1)
    expect(response.parsed_body.fetch('values').fetch('title')).to eq('Newer title')
    expect(release.reload.title).to eq('Newer title')
  end

  it 'returns actionable validation errors and supports the ordinary Save form' do
    sign_in_operator
    patch release_path(release), params: { edit: { expected_revision: 0, title: '' } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch('message')).to include('titre')
    patch release_path(release), params: { edit: { expected_revision: 0, title: 'Saved title' } }
    expect(response).to redirect_to(release_path(release))
  end
end
