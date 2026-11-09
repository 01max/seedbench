require 'rails_helper'

RSpec.describe 'Reviewed payload preparation' do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }

  it 'saves displayed metadata before suggesting a name, then queues only explicit preparation' do
    sign_in_operator
    patch action_release_path(release, kind: 'suggest_name'), params: { edit: { expected_revision: 0, language: 'fr', author: 'Reviewed Author' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('values', 'proposed_name')).to eq('Synthetic.book.Reviewed.Author.FRENCH.[EPUB]-NOTAG')
    expect(release.workflow_operations).to be_empty
    patch action_release_path(release, kind: 'prepare'), params: { edit: { expected_revision: release.reload.input_revision, notes: 'Human notes' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(release.workflow_operations.sole.parameters.fetch('release_name')).to eq(release.reload.proposed_name)
  end

  it 'rejects unlinked shells and stale or forged requests without filesystem effects' do
    sign_in_operator
    shell = Releases::Create.call(title: 'Unlinked')
    patch action_release_path(shell, kind: 'prepare'), params: { edit: { expected_revision: 0 } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    patch action_release_path(release, kind: 'prepare'), params: { edit: { expected_revision: 99 } }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(release.workflow_operations).to be_empty
    expect(Rails.application.config.x.storage.fetch(:payload).glob('staging/*.epub').size).to eq(1)
  end

  it 'protects the files panel behind authentication' do
    get release_preparation_path(release)
    expect(response).to redirect_to(new_operator_session_path)
  end
end
