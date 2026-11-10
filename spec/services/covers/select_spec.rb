require 'rails_helper'

RSpec.describe Covers::Select do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }

  it 'retains actual native pixels, edition review and immutable selection history without hosting' do
    first = choose_manual_cover(release, bytes: cover_bytes(width: 300, height: 450))
    second = choose_manual_cover(release)
    expect([ first.width, first.height, second.number ]).to eq([ 300, 450, 2 ])
    expect(second.edition_evidence).to include('edition_match' => true, 'quality_reviewed' => true)
    expect(second.edition_evidence.fetch('reviewed_facts').fetch('title')).to eq(release.title)
    expect(Covers::Asset.read(locator: second.source_locator, sha256: second.edition_evidence['sha256'])).to start_with("\x89PNG".b)
    expect(release.cover_hostings).to be_empty
  end

  it 'keeps full human content and rejects stale selections after a newer save' do
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { bbcode: 'Human BBCode', nfo: 'Human NFO' })
    choose_manual_cover(release)
    expect(Releases::EditorValues.call(release: release.reload)).to include('bbcode' => 'Human BBCode', 'nfo' => 'Human NFO')
    expect do
      described_class.call(release_id: release.id, expected_revision: 0, kind: 'manual', attributes: {}, review: cover_review)
    end.to raise_error(Releases::RevisionConflict)
  end

  it 'requires edition and quality confirmation and documents nonportrait detail' do
    expect { choose_manual_cover(release, review: { edition_match: true }) }.to raise_error(Covers::Failure, /Confirmez/)
    image = cover_bytes(width: 900, height: 600)
    expect { choose_manual_cover(release, bytes: image) }.to raise_error(Covers::Failure, /non portrait/)
    cover = choose_manual_cover(release, bytes: image, review: cover_review.merge(comparable_detail: '1'))
    expect([ cover.width, cover.height ]).to eq([ 900, 600 ])
  end

  it 'rejects HTML, vector input and an oversized file instead of certifying an image' do
    [ '<html>Not an image</html>', '<svg xmlns="http://www.w3.org/2000/svg"></svg>' ].each do |bytes|
      expect { choose_manual_cover(release, bytes: bytes) }.to raise_error(Covers::Failure, /Image illisible/)
    end
    expect { Covers::Image.call(bytes: 'x' * (Covers::Fetch::MAX_BYTES + 1)) }.to raise_error(Covers::Failure, /8 Mio/)
    expect(release.cover_revisions).to be_empty
  end

  it 'browses edition-linked online candidates without assuming an ISBN proves a digital edition' do
    record = { key: '/books/OL123M', title: 'Synthetic book', covers: [ 1234 ], isbn_13: [ '9780306406157' ], publishers: [ 'Publisher' ], physical_format: 'Paperback' }
    stub_request(:get, 'https://openlibrary.org/isbn/9780306406157.json').to_return(body: JSON.generate(record))
    operation = Ebooks::Action.call(release_id: release.id, kind: 'lookup', expected_revision: 0, isbn: '9780306406157')
    Workflows::Execute.call(operation_id: operation.id)
    candidate = Covers::Workspace.call(release: release.reload).candidates.sole
    allow(Resolv).to receive(:getaddresses).with('covers.openlibrary.org').and_return([ '93.184.216.34' ])
    stub_request(:get, candidate.fetch(:url)).to_return(body: cover_bytes, headers: { 'Content-Type' => 'image/png' })
    cover = described_class.call(release_id: release.id, expected_revision: 0, kind: 'online',
      attributes: { evidence_id: candidate.fetch(:evidence).id, candidate_id: 1234 }, review: cover_review)
    expect(cover.edition_evidence.dig('edition_record', 'edition_medium')).to eq('print_record')
    expect(cover.edition_evidence.dig('edition_record', 'queried_isbn')).to eq('9780306406157')
    expect(release.cover_hostings).to be_empty
  end

  it 'selects only embedded evidence belonging to the current release and payload' do
    bytes = cover_bytes
    hash = Digest::SHA256.hexdigest(bytes)
    directory = Preparation::Paths.new.directory('inspection-covers')
    directory.join(hash).binwrite(bytes)
    evidence = release.evidence_items.create!(payload_revision: release.payload_revisions.sole, evidence_key: 'embedded-cover', kind: 'inspection', source: 'Synthetic cover',
      captured_at: Time.current, input_revision: 0, data: { covers: [ { sha256: hash, media_type: 'image/png' } ] })
    cover = described_class.call(release_id: release.id, expected_revision: 0, kind: 'embedded',
      attributes: { evidence_id: evidence.id, candidate_id: hash }, review: cover_review)
    expect(cover.edition_evidence['evidence_id']).to eq(evidence.id)
    other = staged_preparation_release
    expect { described_class.call(release_id: other.id, expected_revision: 0, kind: 'embedded', attributes: { evidence_id: evidence.id, candidate_id: hash }, review: cover_review) }.to raise_error(Covers::Failure)
  end
end
