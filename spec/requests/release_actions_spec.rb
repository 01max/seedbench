require 'rails_helper'

RSpec.describe 'Explicit reviewed actions' do
  it 'saves reviewed inputs but keeps unavailable actions closed without remote or file effects' do
    release = Releases::Create.call(title: 'Synthetic')
    sign_in_operator
    %w[draft publish].each_with_index do |kind, revision|
      patch action_release_path(release, kind: kind), params: { edit: { expected_revision: revision, bbcode: "Text #{revision}" } }, as: :json
      expect(response).to have_http_status(kind == 'draft' ? :unprocessable_content : :service_unavailable)
      expect(release.reload.input_revision).to eq(revision + 1)
    end
    expect(release.remote_snapshots.count).to eq(0)
    expect(release.preparation_revisions.count).to eq(0)
  end

  it 'does not submit an older revision and returns the current saved text' do
    release = Releases::Create.call(title: 'Current')
    sign_in_operator
    patch action_release_path(release, kind: 'publish'), params: { edit: { expected_revision: 3, title: 'Stale' } }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.fetch('values').fetch('title')).to eq('Current')
    expect(release.reload.title).to eq('Current')
  end

  it 'rejects unknown actions and invalid form values' do
    release = Releases::Create.call(title: 'Current')
    sign_in_operator
    patch action_release_path(release, kind: 'unknown'), params: { edit: { expected_revision: 0, title: 'Changed' } }, as: :json
    expect(response).to have_http_status(:bad_request)
    patch action_release_path(release, kind: 'draft'), params: { edit: { expected_revision: 0, title: '' } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(release.reload.title).to eq('Current')
  end
end
