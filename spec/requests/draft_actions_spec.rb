require 'rails_helper'

RSpec.describe 'C411 draft actions' do
  it 'imports immediately on workspace open and shows unlinked shells without a remote write' do
    create_connection
    stub_draft_account
    sign_in_operator
    get root_path
    expect(response.body).to include('Livre distant', 'aucun fichier lié')
    expect(Release.sole.payload_revisions).to be_empty
    expect(WebMock).not_to have_requested(:post, /c411/)
  end

  it 'requires authentication and CSRF for draft reads and mutation forms' do
    release = imported_draft
    get release_draft_action_path(release)
    expect(response).to redirect_to(new_operator_session_path)
    sign_in_operator
    begin
      ActionController::Base.allow_forgery_protection = true
      post release_draft_action_path(release), params: { authenticity_token: 'forged', draft: { kind: 'sync' } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(release.remote_snapshots.count).to eq(1)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  it 'saves current unlinked text before queuing an explicit update' do
    release = imported_draft
    sign_in_operator
    patch action_release_path(release, kind: 'draft'), params: { edit: { expected_revision: release.input_revision, bbcode: 'Displayed reviewed description' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(release.draft_writes.sole.request.dig('content', 'description')).to eq('Displayed reviewed description')
    expect(release.payload_revisions).to be_empty
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'rejects forged cleanup, preparation and publication on an unlinked shell' do
    release = imported_draft
    sign_in_operator
    post release_draft_action_path(release), params: { draft: { kind: 'delete', expected_revision: release.input_revision, remote_id: 'draft-1', confirmed: '1' } }
    expect(response).to have_http_status(:unprocessable_content)
    %w[prepare publish].each do |kind|
      patch action_release_path(release, kind: kind), params: { edit: { expected_revision: release.input_revision } }, as: :json
      expect(response).not_to have_http_status(:ok)
    end
    expect(release.draft_writes).to be_empty
    expect(WebMock).not_to have_requested(:delete, /c411/)
  end

  it 'requires confirmed missing state for recreation instead of turning a forged recreate form into an update' do
    release = imported_draft
    sign_in_operator
    [ '0', '1' ].each do |confirmed|
      post release_draft_action_path(release), params: { draft: { kind: 'recreate', expected_revision: release.input_revision, confirmed: confirmed } }
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(release.draft_writes).to be_empty
  end

  it 'requires the displayed snapshot to confirm cleanup' do
    release = imported_draft
    release.update!(publication_state: 'published')
    sign_in_operator
    get release_draft_action_path(release)
    expect(response.body).to include('name="draft[snapshot_id]"')

    parameters = { kind: 'delete', expected_revision: release.input_revision, remote_id: 'draft-1', confirmed: '1' }
    post release_draft_action_path(release), params: { draft: parameters }
    expect(response).to have_http_status(:unprocessable_content)
    expect(release.draft_writes).to be_empty

    snapshot = release.remote_snapshots.last
    post release_draft_action_path(release), params: { draft: parameters.merge(snapshot_id: snapshot.id) }
    expect(response).to have_http_status(:ok)
    expect(release.draft_writes.sole.request).to include('snapshot_id' => snapshot.id, 'remote_content' => snapshot.remote_content)
  end

  it 'explains an interrupted accepted write instead of returning an unexpected error or sending again' do
    release = imported_draft
    operation = Drafts::Request.call(release_id: release.id, expected_revision: release.input_revision)
    token = Workflows::Claim.call(operation_id: operation.id)
    operation.draft_write.update!(state: 'accepted', body: Drafts::Content.local(release).except('nfo'))
    Workflows::Fail.call(operation_id: operation.id, attempt_token: token)
    sign_in_operator
    patch action_release_path(release, kind: 'draft'), params: { edit: { expected_revision: release.input_revision } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to include('Réconciliez')
    expect(release.draft_writes.count).to eq(1)
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end
end
