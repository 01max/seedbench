require 'rails_helper'

RSpec.describe Workflows::RecordOutcome do
  let(:release) { build_release_graph }
  let(:operation) { start_synthetic_operation(release) }
  let(:token) { Workflows::Claim.call(operation_id: operation.id) }

  before { install_workflow_definition(effect: 'remote') }

  def record(reference, attempt: token)
    described_class.call(operation_id: operation.id, attempt_token: attempt, phase: 'accepted', reference: reference)
  end

  it 'retains an approved external identity when later inputs change', :aggregate_failures do
    current = token
    Releases::Revise.call(release_id: release.id, expected_revision: 0, changes: { author: 'New author' })
    record({ submission_id: 'synthetic-accepted' }, attempt: current)
    Workflows::Complete.call(operation_id: operation.id, attempt_token: current, result: {}, apply: SyntheticWorkflow::Apply)

    expect(operation.reload.state).to eq('stale')
    expect(operation.external_reference).to eq('submission_id' => 'synthetic-accepted')
    expect(operation.input_revision).to eq(0)
    expect(operation.phase).to eq('accepted')
    expect(release.reload.author).to eq('New author')
  end

  it 'does not replace a recorded external identity' do
    record({ submission_id: 'synthetic-accepted' })

    expect { record({ submission_id: 'another' }) }.to raise_error(described_class::Conflict)
    expect(operation.reload.external_reference).to eq('submission_id' => 'synthetic-accepted')
  end

  it 'treats an identical repeated observation as a no-op' do
    2.times { record({ submission_id: 'synthetic-accepted' }) }

    expect(release.release_events.where(name: 'operation.outcome_recorded').count).to eq(1)
  end

  it 'does not accept an outcome from another attempt' do
    token
    record({ submission_id: 'synthetic-accepted' }, attempt: 'superseded')

    expect(operation.reload.external_reference).to eq({})
  end

  it 'preserves known outcome data after an unexpected non-local failure' do
    id = operation.id
    allow(SyntheticWorkflow::Compute).to receive(:call) do |operation:|
      described_class.call(operation_id: operation.id, attempt_token: operation.attempt_token, phase: 'accepted', reference: { submission_id: 'synthetic-accepted' })
      raise 'Synthetic lost response'
    end

    expect { Workflows::Execute.call(operation_id: id) }.to raise_error(RuntimeError, 'Synthetic lost response')
    expect(operation.reload.state).to eq('outcome_unknown')
    expect(operation.external_reference).to eq('submission_id' => 'synthetic-accepted')
  end
end
