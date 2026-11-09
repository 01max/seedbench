require 'rails_helper'

RSpec.describe Releases::RecordEvent do
  let(:release) { Releases::Create.call }

  it 'records actor, time, sequence and input revision' do
    event = described_class.call(release_id: release.id, name: 'review.checked', data: { checked: true, evidence_ids: [ 1 ] })

    expect(event.sequence).to eq(2)
    expect(event.actor).to eq('system')
    expect(event.input_revision).to eq(0)
    expect(event.occurred_at).to be_present
  end

  it 'rejects secret fields nested inside event metadata' do
    expect { described_class.call(release_id: release.id, name: 'review.checked', data: { nested: { api_key: 'synthetic' } }) }
      .to raise_error(Releases::EventMetadata::Unsafe)
  end

  it 'rejects URLs, arbitrary objects and invalid event labels', :aggregate_failures do
    [ { source: 'https://tracker.invalid/private' }, { value: Object.new }, { data: 'x' * 17_000 } ].each do |data|
      expect { described_class.call(release_id: release.id, name: 'review.checked', data: data) }
        .to raise_error(Releases::EventMetadata::Unsafe)
    end
    expect { described_class.call(release_id: release.id, name: 'invalid name') }
      .to raise_error(Releases::EventMetadata::Unsafe)
  end
end
