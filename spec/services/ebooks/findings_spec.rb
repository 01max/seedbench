require 'rails_helper'

RSpec.describe Ebooks::Findings do
  let(:release) { build_release_graph }
  let(:payload) { release.payload_revisions.sole }

  def measure(key, data)
    release.evidence_items.create!(payload_revision: payload, evidence_key: key, kind: 'inspection', source: 'Synthetic parser',
      captured_at: Time.current, input_revision: release.input_revision, data: data)
    described_class.call(release: release, payload: payload)
  end

  it 'keeps mechanical failures blocking until a new successful measurement' do
    measure('bad', { error: 'corrupt' })
    finding = release.findings.find_by!(code: 'inspection_failure')
    expect { Releases::AcknowledgeFinding.call(release_id: release.id, finding_id: finding.id, number: 1, acknowledged: true, expected_revision: 0) }.to raise_error(Releases::AcknowledgeFinding::NotUncertain)
    measure('good', { error: nil })
    expect(Releases::Snapshot.call(release: release).findings.map(&:code)).not_to include('inspection_failure')
    expect(finding.reload.data).to include('error' => 'corrupt')
    expect(release.findings.where(code: 'inspection_failure').count).to eq(2)
  end

  it 'requires a renewed acknowledgement only when the measured uncertainty changes' do
    measure('first', { structure: { pages_without_text_in_sample: [ 1 ] } })
    finding = release.findings.find_by!(code: 'sampled_pages')
    Releases::AcknowledgeFinding.call(release_id: release.id, finding_id: finding.id, number: 1, acknowledged: true, expected_revision: 0)
    measure('same', { structure: { pages_without_text_in_sample: [ 1 ] } })
    expect(release.findings.where(code: 'sampled_pages').count).to eq(1)
    measure('changed', { structure: { pages_without_text_in_sample: [ 1, 2 ] } })
    current = release.findings.where(code: 'sampled_pages').order(:number).last
    expect(current.finding_acknowledgements).to be_empty
    expect(finding.finding_acknowledgements.sole.acknowledged).to be(true)
  end

  it 'records source-linked edition conflicts and treats invalid reviewed checksums as failures' do
    measure('embedded', { candidates: [ { field: 'isbn', value: '9780306406157', source: 'book.opf' } ] })
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { isbn: '9780140328721' })
    expect(release.findings.find_by!(code: 'edition_conflict').data.to_json).to include('embedded', '9780140328721')
    Releases::Save.call(release_id: release.id, expected_revision: 1, changes: { isbn: '9780306406158' })
    expect(release.findings.find_by!(code: 'invalid_reviewed_isbn').severity).to eq('failure')
  end
end
