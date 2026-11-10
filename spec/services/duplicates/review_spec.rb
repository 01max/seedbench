require 'rails_helper'

RSpec.describe Duplicates::Review do
  let(:release) { reviewed_content_release }
  let(:reason) { 'Édition imprimée distincte ; le fichier contrôlé est un EPUB numérique.' }

  before do
    configure_duplicate_search(release)
    stub_duplicate_search
    search_duplicates(release)
  end

  def review(decision, note: reason)
    assessment = Duplicates::Assessment.new(release.reload)
    result = described_class.call(release_id: release.id, expected_revision: release.input_revision, check_id: assessment.check.id,
      candidate_key: assessment.candidates.first.evidence.fetch('key'), decision: decision, reason: note)
    release.reload
    result
  end

  def assessment
    Duplicates::Assessment.new(release.reload)
  end

  def manual(note: reason)
    described_class.manual_exception(release_id: release.id, expected_revision: release.reload.input_revision,
      check_id: assessment.check.id, reason: note)
  end

  it 'blocks unreviewed matches, tags confirmations and retains reasoned overrides without rewriting history' do
    expect(assessment).to be_blocked
    confirmed = review('confirmed', note: '')
    expect(assessment).to be_confirmed
    expect(Releases::Queue.call(state: 'duplicate').records).to include(release)
    review('false_positive')
    expect(assessment).to be_ready
    expect(confirmed.reload.decision).to eq('confirmed')
  end

  it 'requires an explicit reason for false positives and refuses generic clear or foreign candidates' do
    expect { review('false_positive', note: 'No') }.to raise_error(Duplicates::Failure, /Documentez/)
    expect { review('clear') }.to raise_error(Duplicates::Failure)
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision, check_id: assessment.check.id,
      candidate_key: 'foreign', decision: 'confirmed') }.to raise_error(Duplicates::Failure)
    expect(assessment).to be_blocked
  end

  it 'keeps reviews relevant across prose changes but invalidates them for changed edition facts' do
    review('false_positive')
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { notes: 'Human notes' })
    expect(assessment).to be_ready
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { edition: 'Another edition' })
    expect(assessment).not_to be_ready
    search_duplicates(release)
    expect(assessment).to be_blocked
  end

  it 'does not clear known confirmed matches when a later feed omits them' do
    review('confirmed')
    stub_duplicate_search(body: '<rss><channel/></rss>')
    search_duplicates(release)
    expect(assessment).to be_confirmed
    expect(assessment).to be_blocked
    expect(assessment.candidates.size).to eq(1)
  end

  it 'rejects decisions from another release, older results or a stale editor revision' do
    older = assessment.check
    search_duplicates(release)
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision, check_id: older.id,
      candidate_key: older.candidates.first['key'], decision: 'confirmed') }.to raise_error(Duplicates::Failure, /Actualisez/)
    expect { described_class.call(release_id: release.id, expected_revision: -1, check_id: assessment.check.id,
      candidate_key: assessment.candidates.first.evidence['key'], decision: 'confirmed') }.to raise_error(Releases::RevisionConflict)
  end

  it 'allows only the search availability exception and still blocks every known match' do
    review('confirmed')
    stub_duplicate_search(body: '<error code="503"/>')
    search_duplicates(release)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: '{"success":true,"data":[]}')
    manual
    expect(assessment).to be_manual_exception
    expect(assessment).to be_blocked
    expect(assessment).not_to be_ready
    review('false_positive')
    expect(assessment).to be_ready
  end

  it 'requires a fresh manual note for each failed search and checks account availability without writing' do
    review('false_positive')
    stub_duplicate_search(body: '<error/>')
    search_duplicates(release)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: '{"success":true,"data":[]}')
    expect { manual(note: 'ok') }.to raise_error(Duplicates::Failure)
    manual
    expect(assessment).to be_ready
    search_duplicates(release)
    expect(assessment).not_to be_manual_exception
    expect(assessment).not_to be_ready
    expect(WebMock).not_to have_requested(:post, %r{c411.org})
  end

  it 'refuses the exception if C411 account access also fails or the feed is merely truncated' do
    expect { manual }.to raise_error(Duplicates::Failure)
    stub_duplicate_search(body: '<error/>')
    search_duplicates(release)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 503)
    expect { manual }.to raise_error(Duplicates::Failure, /aussi indisponible/)
    expect(assessment).not_to be_ready
  end
end
