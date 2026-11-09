require 'rails_helper'

RSpec.describe 'Local operation status' do
  it 'returns only status HTML and derives polling from durable operations' do
    release = Releases::Create.call(title: 'Private editor title')
    release.workflow_operations.create!(kind: 'synthetic', request_key: 'pending', effect: 'local', input_revision: 0)
    sign_in_operator
    get release_status_path(release)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-active-operations="true"', 'data-status-sequence="1"')
    expect(response.body).not_to include('id="release-editor"', 'Private editor title', 'textarea')
  end

  it 'stops automatic status reads for completed and uncertain operations' do
    release = Releases::Create.call
    release.workflow_operations.create!(kind: 'synthetic', request_key: 'unknown', effect: 'remote', input_revision: 0, state: 'outcome_unknown')
    sign_in_operator
    get release_status_path(release)

    expect(response.body).to include('data-active-operations="false"', 'Résultat incertain')
  end

  it 'protects status reads from unauthenticated access' do
    release = Releases::Create.call
    get release_status_path(release)

    expect(response).to redirect_to(new_operator_session_path)
  end

  it 'retains the observed phase and known external identity for uncertain outcomes' do
    release = Releases::Create.call
    release.workflow_operations.create!(kind: 'synthetic', request_key: 'accepted', effect: 'remote', input_revision: 0,
      state: 'outcome_unknown', phase: 'accepted', external_reference: { submission_id: 'known-submission' })
    sign_in_operator
    get release_status_path(release)

    expect(response.body).to include('Acceptation observée', 'known-submission', 'Résultat incertain')
  end
end
