require 'rails_helper'

RSpec.describe Ebooks::Readiness do
  let(:release) { build_release_graph }

  it 'requires a successful inspection even when uncertainty was acknowledged' do
    expect(described_class.call(release: release)).not_to be_empty
    release.update!(inspection_state: 'succeeded')
    expect(described_class.call(release: release)).to be_empty
  end

  it 'rejects a deterministic failure despite manual review marks' do
    release.update!(inspection_state: 'succeeded')
    release.findings.create!(payload_revision: release.payload_revisions.sole, code: 'broken', number: 1,
      severity: 'failure', message: 'Unreadable content', input_revision: 0)
    Releases::MarkCheck.call(release_id: release.id, key: 'edition_review', checked: true, expected_revision: 0)
    expect(described_class.call(release: release)).to include('Unreadable content')
  end
end
