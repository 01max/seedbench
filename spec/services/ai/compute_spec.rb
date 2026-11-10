require 'rails_helper'

RSpec.describe Ai::Compute do
  let(:release) { reviewed_content_release }

  before { configure_ai(release) }

  def execute(run)
    Workflows::Execute.call(operation_id: run.workflow_operation_id)
    run.reload
  end

  it 'persists the request, identifiers, exact prompt/model and validated result without reviewing any fact' do
    run = build_ai_run(release)
    original = release.reviewed_facts.count
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: ai_response(ai_output(run.request['pack'])))
    execute(run)
    expect(run).to have_attributes(status: 'succeeded', model: 'gpt-4.1-mini-2025-04-14', prompt_version: 'evidence-only-v1/assessment-v1')
    expect(run.evidence_keys).to eq(run.request['pack']['items'].pluck('id'))
    expect(run.result).to include('response_id' => 'resp_synthetic', 'usage' => include('total_tokens' => 180))
    expect(release.reviewed_facts.count).to eq(original)
    expect { run.update!(result: {}) }.to raise_error(ActiveRecord::StatementInvalid, /immutable/)
  end

  it 'retains a valid late result as stale without replacing newer human text' do
    run = build_ai_run(release, purpose: 'prose')
    token = Workflows::Claim.call(operation_id: run.workflow_operation_id)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: ai_response(ai_output(run.request['pack'], purpose: 'prose')))
    result = described_class.call(operation: run.workflow_operation.reload)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { nfo: 'New human NFO' })
    Workflows::Complete.call(operation_id: run.workflow_operation_id, attempt_token: token, result: result, apply: Ai::Record)
    expect(run.reload.status).to eq('stale')
    expect(run.result.dig('output', 'presentation')).to be_present
    expect(Releases::EditorValues.call(release: release.reload)['nfo']).to eq('New human NFO')
  end

  it 'records sanitized provider failures and rejects forbidden output as unusable' do
    run = build_ai_run(release)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(status: 401, body: 'synthetic-openai-key')
    expect(execute(run)).to have_attributes(status: 'failed', error_code: 'http_401')
    other = build_ai_run(release)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: ai_response(ai_output(other.request['pack']).merge('publish' => true)))
    expect(execute(other)).to have_attributes(status: 'unusable', error_code: 'invalid_output')
    expect(other.result.to_json).not_to include('publish', 'synthetic-openai-key')
  end

  it 'does not bill again after an interrupted run or execute a stale queued request' do
    run = build_ai_run(release)
    run.update!(status: 'running')
    expect(execute(run)).to have_attributes(status: 'unusable', error_code: 'interrupted')
    other = build_ai_run(release)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { notes: 'New notes' })
    execute(other)
    expect(other.status).to eq('stale')
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/responses')
  end
end
