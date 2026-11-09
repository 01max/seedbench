require 'rails_helper'

RSpec.describe 'Content review actions' do
  let(:release) { reviewed_content_release }

  it 'requires authentication for proposals and stored text' do
    get release_content_action_path(release)
    expect(response).to redirect_to(new_operator_session_path)
    post release_content_action_path(release), params: { content: { kind: 'propose_bbcode', expected_revision: release.input_revision } }
    expect(response).to redirect_to(new_operator_session_path)
    expect(release.content_proposals).to be_empty
  end

  it 'creates a reviewable proposal and accepts it through a bounded frame response' do
    sign_in_operator
    post release_content_action_path(release), params: { content: { kind: 'propose_bbcode', expected_revision: release.input_revision } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Version enregistrée', 'Accepter cette proposition')
    proposal = release.content_proposals.sole
    post release_content_action_path(release), params: { content: { kind: 'accept', proposal_id: proposal.id, expected_revision: release.input_revision } }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('id="release-editor"')
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq(proposal.bodies['bbcode'])
  end

  it 'rejects stale requests and forged content actions' do
    sign_in_operator
    post release_content_action_path(release), params: { content: { kind: 'propose_nfo', expected_revision: 100 } }
    expect(response).to have_http_status(:conflict)
    post release_content_action_path(release), params: { content: { kind: 'publish', expected_revision: release.input_revision } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(release.content_proposals).to be_empty
  end
end
