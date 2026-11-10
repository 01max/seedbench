require 'rails_helper'

RSpec.describe 'Optional AI assistance' do
  let(:release) { reviewed_content_release }

  it 'protects evidence and generation actions with operator authentication' do
    get release_ai_action_path(release)
    expect(response).to redirect_to(new_operator_session_path)
    post release_ai_action_path(release), params: { assistance: { expected_revision: release.input_revision, purpose: 'prose' } }
    expect(response).to redirect_to(new_operator_session_path)
  end

  it 'queues an explicit request without exposing the provider key or changing prose' do
    sign_in_operator
    configure_ai(release)
    original = Releases::EditorValues.call(release: release)
    post release_ai_action_path(release), params: { assistance: { expected_revision: release.input_revision, purpose: 'prose' } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Demande enregistrée', 'En attente')
    expect(response.body).not_to include('synthetic-openai-key')
    expect(Releases::EditorValues.call(release: release.reload)).to eq(original)
  end
end
