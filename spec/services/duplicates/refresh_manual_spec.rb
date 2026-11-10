require 'rails_helper'

RSpec.describe Duplicates::Refresh do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  let(:release) { reviewed_content_release }

  before do
    configure_duplicate_search(release)
    stub_duplicate_search(body: '<error code="503"/>')
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: '{"success":true,"data":[]}')
  end

  def refresh(operation)
    described_class.call(operation_id: operation.id, attempt_token: operation.attempt_token)
  end

  def failed_publish_check
    expect { refresh(cover_write_operation(release, kind: 'publish')) }.to raise_error(Duplicates::Failure)
    Duplicates::Assessment.new(release.reload).check
  end

  def review_manually(check)
    Duplicates::Review.manual_exception(release_id: release.id, expected_revision: release.reload.input_revision, check_id: check.id,
      reason: 'Manual title, author, ISBN, edition and format search found no matching release.')
    Duplicates::Assessment.new(release.reload).check
  end

  def continuation(check)
    cover_write_operation(release, kind: 'publish', parameters: { 'manual_search_check_id' => check.id })
  end

  it 'continues the approved manually reviewed Publish search without invalidating its note' do
    check = review_manually(failed_publish_check)
    expect(refresh(continuation(check))).to eq(check)
    expect(Duplicates::Assessment.new(release.reload)).to be_ready
    expect(WebMock).to have_requested(:get, %r{c411.org/api\?}).once
    expect(WebMock).to have_requested(:get, 'https://c411.org/api/user/drafts').twice
    expect(WebMock).not_to have_requested(:post, %r{c411.org})
  end

  it 'performs a fresh search and requires a fresh note without an approved continuation' do
    check = review_manually(failed_publish_check)
    expect { refresh(cover_write_operation(release, kind: 'publish')) }.to raise_error(Duplicates::Failure)
    assessment = Duplicates::Assessment.new(release.reload)
    expect(assessment).not_to be_manual_exception
    expect(assessment.check.query['search_id']).not_to eq(check.query['search_id'])
  end

  it 'rejects an unreviewed check and a review superseded by another search' do
    failed = failed_publish_check
    expect { refresh(continuation(failed)) }.to raise_error(Duplicates::Failure)
    reviewed = review_manually(failed)
    search_duplicates(release)
    expect { refresh(continuation(reviewed)) }.to raise_error(Duplicates::Failure)
  end

  it 'requires a failed Publish search instead of using a local search to bypass refresh' do
    reviewed = review_manually(search_duplicates(release))
    expect { refresh(continuation(reviewed)) }.to raise_error(Duplicates::Failure)
    expect(WebMock).to have_requested(:get, 'https://c411.org/api/user/drafts').once
  end

  it 'keeps known candidates blocking a manually reviewed continuation' do
    stub_duplicate_search
    stub_request(:get, %r{c411.org/api\?}).with(query: hash_including('q' => 'Synthetic book Test author')).to_return(status: 503)
    reviewed = review_manually(failed_publish_check)
    expect(Duplicates::Assessment.new(release.reload)).to be_blocked
    expect { refresh(continuation(reviewed)) }.to raise_error(Duplicates::Failure)
  end

  it 'rejects changed edition facts before continuing' do
    reviewed = review_manually(failed_publish_check)
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { edition: 'Changed edition' })
    expect { refresh(continuation(reviewed)) }.to raise_error(Duplicates::Failure)
  end

  it 'rechecks C411 account access before allowing the continuation' do
    reviewed = review_manually(failed_publish_check)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 503)
    expect { refresh(continuation(reviewed)) }.to raise_error(Duplicates::Failure, /aussi indisponible/)
    expect(WebMock).to have_requested(:get, %r{c411.org/api\?}).once
  end

  it 'fences edits made during the account-access recheck' do
    reviewed = review_manually(failed_publish_check)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return do
      Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { notes: 'Edited during access check' })
      { body: '{"success":true,"data":[]}' }
    end
    expect { refresh(continuation(reviewed)) }.to raise_error(Releases::RevisionConflict)
  end
end
