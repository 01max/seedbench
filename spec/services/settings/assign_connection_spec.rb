require 'rails_helper'

RSpec.describe Settings::AssignConnection do
  let(:release) { Releases::Create.call }
  let(:connection) { create_connection }

  def assign(connection_id: connection.id, revision: release.input_revision)
    described_class.call(release_id: release.id, role: 'publishing', connection_id: connection_id, expected_revision: revision)
  end

  it 'requires a deliberate assignment and records it atomically' do
    assign

    expect(release.reload.input_revision).to eq(1)
    expect(release.provider_assignments.find_by!(role: 'publishing').provider_connection).to eq(connection)
    expect(release.release_events.last.name).to eq('provider.assigned')
    expect(WorkflowOperation.count).to eq(0)
  end

  it 'keeps existing identities and makes an identical assignment a no-op' do
    assign
    assign(revision: 1)
    other = create_connection(identity: 'different-account')
    expect { assign(connection_id: other.id, revision: 1) }.to raise_error(described_class::AlreadyAssigned)
    expect(release.reload.input_revision).to eq(1)
    expect(release.release_events.where(name: 'provider.assigned').count).to eq(1)
  end

  it 'rejects stale revisions and mismatched roles' do
    expect { assign(revision: 99) }.to raise_error(Releases::RevisionConflict)
    ai = create_connection('ai')
    expect { assign(connection_id: ai.id) }.to raise_error(Settings::SetDefaults::Invalid)
  end

  it 'rolls back the assignment if recording history fails' do
    release
    allow(Releases::RecordEvent).to receive(:call).and_raise(ActiveRecord::StatementInvalid)
    expect { assign }.to raise_error(ActiveRecord::StatementInvalid)
    expect(release.provider_assignments.find_by!(role: 'publishing').provider_connection_id).to be_nil
    expect(release.reload.input_revision).to eq(0)
  end
end
