require 'rails_helper'

RSpec.describe Releases::Transition do
  let(:release) { Releases::Create.call }

  it 'changes one dimension and records history without revising inputs' do
    described_class.call(release_id: release.id, dimension: 'inspection', to: 'running', expected_revision: 0)

    expect(release.reload.inspection_state).to eq('running')
    expect(release.preparation_state).to eq('unprepared')
    expect(release.input_revision).to eq(0)
    expect(release.release_events.order(:sequence).last.data).to eq('from' => 'pending', 'to' => 'running')
  end

  it 'rejects publication transitions that skip submission' do
    expect { described_class.call(release_id: release.id, dimension: 'publication', to: 'published', expected_revision: 0) }
      .to raise_error(described_class::NotAllowed) { |error| expect(error.from).to eq('unpublished') }
    expect(release.reload.publication_state).to eq('unpublished')
  end

  it 'rejects arbitrary dimension names' do
    expect { described_class.call(release_id: release.id, dimension: 'destroy', to: 'running', expected_revision: 0) }
      .to raise_error(described_class::NotAllowed)
  end

  it 'rejects a transition against changed inputs' do
    expect { described_class.call(release_id: release.id, dimension: 'inspection', to: 'running', expected_revision: 4) }
      .to raise_error(Releases::RevisionConflict)
  end

  it 'treats a repeated state as a no-op' do
    described_class.call(release_id: release.id, dimension: 'inspection', to: 'pending', expected_revision: 0)

    expect(release.release_events.count).to eq(1)
  end
end
