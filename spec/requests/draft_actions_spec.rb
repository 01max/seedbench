require 'rails_helper'

RSpec.describe 'C411 draft actions' do
  it 'imports on demand and shows queue entries without building an editor or rereading C411 on navigation' do
    connection = create_connection
    stub_draft_account
    sign_in_operator
    post import_drafts_provider_connection_path(connection)
    get root_path(state: 'imported')
    expect(response.body).to include('Livre distant', 'Import C411', 'Brouillon C411 draft-1')
    expect(response.parsed_body.css('.work-footer button').map(&:text)).to eq([ 'Archiver' ])
    expect(response.parsed_body.at_css('#release-editor')).to be_nil
    expect(WebMock).to have_requested(:get, 'https://c411.org/api/user/drafts').once
    expect(WebMock).not_to have_requested(:get, 'https://c411.org/api/user/drafts/draft-1')
  end

  it 'reports account rate limiting on the Publishing settings page' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 429)
    sign_in_operator
    post import_drafts_provider_connection_path(connection)
    follow_redirect!

    expect(response.parsed_body.at_css('[role="alert"]').text).to include('Trop de requêtes (HTTP 429)')
    expect(Release.count).to eq(0)
  end

  it 'synchronizes the linked draft even when the account list is rate limited' do
    release = linked_draft
    linked_draft(draft_data('draft-2'), connection: release.draft_link.provider_connection)
    stub_draft_account(draft_data(description: 'Updated C411 description'))
    account_list = stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 429)
    sign_in_operator

    post release_draft_action_path(release), params: { draft: { kind: 'sync' } }

    expect(response).to have_http_status(:ok)
    expect(Drafts::Content.local(release.reload).fetch('description')).to eq('Updated C411 description')
    expect(account_list).not_to have_been_requested
    expect(WebMock).not_to have_requested(:get, 'https://c411.org/api/user/drafts/draft-2')
  end

  it 'requires a linked draft to enable or accept synchronization' do
    release = Releases::Create.call(title: 'Local book', publishing_connection: create_connection)
    sign_in_operator

    get release_draft_action_path(release)
    expect(response.parsed_body.at_css('input[value="Synchroniser maintenant"][disabled]')).to be_present

    post release_draft_action_path(release), params: { draft: { kind: 'sync' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css('[role="alert"]').text).to include('Associez un brouillon C411')
    expect(WebMock).not_to have_requested(:get, /c411/)
  end

  it 'forbids the editor and nested actions for legacy C411 imports' do
    release = linked_draft
    Releases::RecordEvent.call(release_id: release.id, name: 'draft.imported', data: { remote_id: 'draft-1' })
    revision = release.input_revision
    sign_in_operator

    patch release_path(release), params: { edit: { expected_revision: revision, title: 'Forbidden' } }, as: :json
    expect(response).to have_http_status(:forbidden)
    patch action_release_path(release, kind: 'draft'), params: { edit: { expected_revision: revision } }, as: :json
    expect(response).to have_http_status(:forbidden)
    post release_draft_action_path(release), params: { draft: { kind: 'sync' } }
    expect(response).to have_http_status(:forbidden)
    get release_connections_path(release)
    expect(response).to have_http_status(:forbidden)

    expect(release.reload).to have_attributes(title: 'Livre distant', input_revision: revision)
  end

  it 'requires authentication and CSRF for draft reads and mutation forms' do
    release = linked_draft
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
    release = linked_draft
    sign_in_operator
    patch action_release_path(release, kind: 'draft'), params: { edit: { expected_revision: release.input_revision, bbcode: 'Displayed reviewed description' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(release.draft_writes.sole.request.dig('content', 'description')).to eq('Displayed reviewed description')
    expect(release.payload_revisions).to be_empty
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'rejects forged cleanup, preparation and publication on an unlinked shell' do
    release = linked_draft
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
    release = linked_draft
    sign_in_operator
    [ '0', '1' ].each do |confirmed|
      post release_draft_action_path(release), params: { draft: { kind: 'recreate', expected_revision: release.input_revision, confirmed: confirmed } }
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(release.draft_writes).to be_empty
  end

  it 'requires the displayed snapshot to confirm cleanup' do
    release = linked_draft
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
    release = linked_draft
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
