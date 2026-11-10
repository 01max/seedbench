require 'rails_helper'

RSpec.describe Duplicates::Refresh do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  let(:release) { reviewed_content_release }

  before { configure_duplicate_search(release) }

  def refresh(operation = cover_write_operation(release, kind: 'publish'))
    described_class.call(operation_id: operation.id, attempt_token: operation.attempt_token)
  end

  def reject_candidate(check)
    Duplicates::Review.call(release_id: release.id, expected_revision: release.reload.input_revision, check_id: check.id,
      candidate_key: check.candidates.sole['key'], decision: 'false_positive', reason: 'Édition différente après contrôle de la fiche et du fichier.')
  end

  it 'rechecks immediately and stops for newly discovered candidates without making a publication write' do
    stub_duplicate_search(body: '<rss><channel/></rss>')
    expect(refresh.query['status']).to eq('complete')
    stub_duplicate_search
    expect { refresh }.to raise_error(Duplicates::Failure, /nouveaux candidats/i)
    expect(release.duplicate_checks.last.candidates.size).to eq(1)
    expect(WebMock).not_to have_requested(:post, %r{c411.org})
  end

  it 'retains applicable reviewed false positives but blocks changed evidence and known confirmations' do
    stub_duplicate_search
    expect { refresh }.to raise_error(Duplicates::Failure)
    reject_candidate(release.duplicate_checks.last)
    expect(refresh.query['status']).to eq('complete')
    stub_duplicate_search(body: duplicate_feed(description: 'Autre édition et ISBN'))
    expect { refresh }.to raise_error(Duplicates::Failure)
    expect(Duplicates::Assessment.new(release.reload).candidates.size).to eq(2)
  end

  it 'blocks search failures and refuses a stale action before searching' do
    stub_duplicate_search(body: '<error/>')
    expect { refresh }.to raise_error(Duplicates::Failure)
    operation = cover_write_operation(release, kind: 'publish')
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { notes: 'Later review' })
    expect { refresh(operation) }.to raise_error(Releases::RevisionConflict)
    expect(release.duplicate_checks.last.query['status']).to eq('unavailable')
  end

  it 'discards late results when facts change during network I/O' do
    stub_request(:get, %r{c411.org/api\?}).to_return do
      current = Release.find(release.id)
      Releases::Save.call(release_id: release.id, expected_revision: current.input_revision, changes: { edition: 'Changed during search' })
      { body: '<rss><channel/></rss>' }
    end
    expect { refresh }.to raise_error(Releases::RevisionConflict)
    expect(release.duplicate_checks.count).to eq(1)
  end

  it 'refuses local, expired or transaction-wrapped operations before network I/O' do
    expect { refresh(cover_write_operation(release)) }.to raise_error(Duplicates::Failure)
    operation = cover_write_operation(release, kind: 'publish')
    operation.update!(lease_expires_at: 1.second.ago)
    expect { refresh(operation) }.to raise_error(Duplicates::Failure)
    ApplicationRecord.transaction { expect { refresh(operation) }.to raise_error(Duplicates::Failure, /transaction/) }
    expect(WebMock).not_to have_requested(:get, %r{c411.org})
  end
end
