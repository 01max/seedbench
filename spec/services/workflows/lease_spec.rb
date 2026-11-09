require 'rails_helper'

RSpec.describe Workflows::Lease do
  let(:release) { build_release_graph }
  let(:operation) { start_synthetic_operation(release) }

  before { install_workflow_definition }

  it 'reclaims interrupted local work and fences the old attempt', :aggregate_failures do
    first = Workflows::Claim.call(operation_id: operation.id)
    operation.update!(lease_expires_at: 1.second.ago)
    described_class.recover(limit: 1)
    second = Workflows::Claim.call(operation_id: operation.id)
    Workflows::Complete.call(operation_id: operation.id, attempt_token: first, result: {}, apply: SyntheticWorkflow::Apply)

    expect(second).not_to eq(first)
    expect(operation.reload.attempts).to eq(2)
    expect(operation.state).to eq('running')
    expect(release.evidence_items.where(evidence_key: "workflow-#{operation.id}")).to be_empty
  end

  it 'keeps an active attempt intact' do
    token = Workflows::Claim.call(operation_id: operation.id)

    expect(described_class.recover(limit: 1)).to eq([])
    expect(operation.reload.attempt_token).to eq(token)
  end

  it 'renews only a current unexpired attempt' do
    token = Workflows::Claim.call(operation_id: operation.id)
    operation.update!(lease_expires_at: 1.minute.from_now)

    expect(described_class.renew(operation_id: operation.id, attempt_token: 'wrong')).to be(false)
    expect(described_class.renew(operation_id: operation.id, attempt_token: token)).to be(true)
    expect(operation.reload.lease_expires_at).to be > 4.minutes.from_now
  end

  it 'refuses to renew an expired attempt' do
    token = Workflows::Claim.call(operation_id: operation.id)
    operation.update!(lease_expires_at: 1.second.ago)

    expect(described_class.renew(operation_id: operation.id, attempt_token: token)).to be(false)
  end

  %w[remote filesystem].each do |effect|
    context "with #{effect} effects" do
      before { install_workflow_definition(effect: effect) }

      it 'retains an unknown outcome instead of replaying an interrupted effect' do
        Workflows::Claim.call(operation_id: operation.id)
        operation.update!(lease_expires_at: 1.second.ago)
        described_class.recover(limit: 1)

        expect(operation.reload.state).to eq('outcome_unknown')
        expect(operation.dispatch_intent.reload.state).to eq('dispatched')
        expect(Workflows::RecoverDispatches.call(limit: 1)).to eq([])
      end
    end
  end

  it 'bounds recovery batches' do
    expect { Workflows::RecoverDispatches.call(limit: 0) }.to raise_error(ArgumentError)
  end
end
