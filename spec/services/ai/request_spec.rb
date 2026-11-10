require 'rails_helper'

RSpec.describe Ai::Request do
  let(:release) { reviewed_content_release }

  before { configure_ai(release) }

  def request(purpose: 'assessment', initial: false)
    described_class.call(release_id: release.id, expected_revision: release.reload.input_revision, purpose: purpose, initial: initial)
  end

  it 'records a bounded reproducible request and explicit provider identity before dispatch' do
    run = request
    expect(run.request).to include('context' => Ai::Context.call(release: release), 'initial' => false)
    expect(run.request['content_bases']).to include('presentation')
    expect(run.workflow_operation).to have_attributes(state: 'pending', kind: 'ai_assessment')
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/responses')
  end

  it 'prevents duplicate active requests and allows a deliberate rerun after failure' do
    run = request
    expect { request }.to raise_error(Ai::Failure, /déjà/)
    run.update!(status: 'failed', error_code: 'http_503')
    expect(request.id).not_to eq(run.id)
  end

  it 'uses the recorded per-release automatic choice and schedules each initial purpose once' do
    release.update!(automatic_ai: false)
    Ai::Initial.call(release: release)
    expect(release.ai_runs.where.not(workflow_operation_id: nil)).to be_empty
    release.update!(automatic_ai: true)
    2.times { Ai::Initial.call(release: release) }
    expect(release.ai_runs.where.not(workflow_operation_id: nil).pluck(:purpose)).to contain_exactly('assessment', 'prose')
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/responses')
  end

  it 'starts both optional purposes only after successful inspection evidence is retained' do
    operation = Workflows::Start.call(release_id: release.id, kind: 'inspection', request_key: SecureRandom.uuid,
      expected_revision: release.input_revision, parameters: { payload_revision_id: release.payload_revisions.sole.id, ocr: false })
    report = release.evidence_items.where(kind: 'inspection').last.data.deep_dup
    Ebooks::Record.call(operation: operation, result: report)
    expect(release.ai_runs.where.not(workflow_operation_id: nil).pluck(:purpose)).to contain_exactly('assessment', 'prose')
    expect(release.ai_runs.where.not(workflow_operation_id: nil).last.request.dig('pack', 'items').pluck('id')).to be_present
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/responses')
  end

  it 'keeps manual review available when the role is missing or inspection failed' do
    release.provider_assignments.find_by!(role: 'ai').update!(provider_connection_id: nil)
    expect { request }.to raise_error(Ai::Failure, /revue manuelle/)
    expect { Ai::Initial.call(release: release) }.not_to(change { release.ai_runs.count })
    expect { Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'nfo') }.to change { release.content_proposals.count }.by(1)
  end
end
