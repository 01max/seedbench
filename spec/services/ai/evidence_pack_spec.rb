require 'rails_helper'

RSpec.describe Ai::EvidencePack do
  let(:release) { reviewed_content_release }

  def add_samples(count: 10)
    release.evidence_items.create!(payload_revision: release.payload_revisions.sole, kind: 'inspection', evidence_key: 'focused-report',
      source: 'Synthetic EPUB', captured_at: Time.current, input_revision: release.input_revision,
      data: { metadata: [ { field: 'title', value: 'Synthetic book' } ], structure: { spine_documents: count },
        contents: [ { source: 'contents.xhtml', text: 'Sommaire des chapitres' } ],
        samples: Array.new(count) { |index| { source: "chapter-#{index}.xhtml", text: "Extrait #{index} " + ('é' * 4000) } } })
  end

  it 'sends bounded metadata, contents and opening/ending samples with stable IDs, without reading the payload' do
    add_samples
    first = described_class.call(release: release)
    expect(first).to include('whole_book' => false, 'scope' => { 'mode' => 'routine' })
    expect(first['items'].select { |item| item['kind'] == 'excerpt' }.pluck('source')).to eq(%w[chapter-0.xhtml chapter-1.xhtml chapter-9.xhtml])
    expect(first['items'].pluck('kind')).to include('reviewed', 'metadata', 'structure', 'contents')
    expect(JSON.generate(first).bytesize).to be <= described_class::MAX_BYTES
    expect(described_class.call(release: release)).to eq(first)
  end

  it 'requires explicit scope for additional retained excerpts and records the exact selection' do
    add_samples
    item = Ai::EvidenceCatalog.call(release: release).find { |entry| entry['source'] == 'chapter-5.xhtml' }
    pack = described_class.call(release: release, scope: { mode: 'selected', note: 'Comparer ce chapitre pour la revue ciblée.', evidence_ids: [ item['id'] ] })
    expect(pack['items'].sole).to include('id' => item['id'], 'truncated' => true)
    expect(pack['items'].sole['text'].valid_encoding?).to be(true)
    expect(pack.dig('scope', 'note')).to include('revue ciblée')
    expect { described_class.call(release: release, scope: { mode: 'selected', evidence_ids: [ 'foreign' ], note: 'No' }) }.to raise_error(Ai::Failure)
  end

  it 'rejects a failed latest inspection and does not fall back to older successful evidence' do
    release.evidence_items.create!(payload_revision: release.payload_revisions.sole, kind: 'inspection', evidence_key: 'failed-current',
      source: 'Synthetic failure', captured_at: Time.current, input_revision: release.input_revision, data: { error: 'corrupt' })
    expect { described_class.call(release: release) }.to raise_error(Ai::Failure, /inspection réussie/)
  end

  it 'keeps ISBN records as source evidence and excludes other payload revisions' do
    add_samples
    release.evidence_items.create!(payload_revision: release.payload_revisions.sole, kind: 'edition_record', evidence_key: 'edition-record',
      source: 'Open Library', captured_at: Time.current, input_revision: release.input_revision,
      data: { queried_isbn: '9780306406157', edition_medium: 'print_record', metadata: [ { field: 'publisher', value: 'Synthetic publisher' } ] })
    pack = described_class.call(release: release)
    expect(pack['items'].find { |item| item['kind'] == 'edition' }['text']).to include('print_record', '9780306406157')
    expect(pack['items'].pluck('id').uniq.size).to eq(pack['items'].size)
  end
end
