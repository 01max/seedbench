require 'rails_helper'

RSpec.describe Duplicates::Search do
  let(:release) { reviewed_content_release }

  before { configure_duplicate_search(release) }

  def search_with_later_failure(body)
    stub_duplicate_search(body: body)
    stub_request(:get, %r{c411.org/api\?}).with(query: hash_including('q' => 'Synthetic book Test author')).to_return(status: 503)
    search_duplicates(release)
  end

  def reject_visible_candidate(check)
    Duplicates::Review.call(release_id: release.id, expected_revision: release.reload.input_revision, check_id: check.id,
      candidate_key: check.candidates.sole.fetch('key'), decision: 'false_positive', reason: 'Different edition after checking the actual file and ISBN.')
    release.reload.duplicate_checks.order(:id).last
  end

  def manual_exception(check)
    Duplicates::Review.manual_exception(release_id: release.id, expected_revision: release.reload.input_revision,
      check_id: check.id, reason: 'Manual title, author, ISBN, edition and format search performed.')
  end

  it 'keeps truncation blocking after a later query fails and visible candidates are rejected' do
    body = duplicate_feed
    full = body.sub('</item>', '</item>' + (body[/<item>.*?<\/item>/m] * 99))
    check = search_with_later_failure(full)
    expect(check.query).to include('status' => 'incomplete', 'failure_code' => 'http_503')
    reviewed = reject_visible_candidate(check)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: '{"success":true,"data":[]}')
    expect { manual_exception(reviewed) }.to raise_error(Duplicates::Failure)
    expect(Duplicates::Assessment.new(release.reload)).not_to be_ready
  end

  it 'retains unidentifiable result evidence as incomplete when another query fails' do
    body = duplicate_feed.sub('</channel>', '<item><title>Unidentified candidate</title></item></channel>')
    check = search_with_later_failure(body)
    expect(check.query).to include('status' => 'incomplete', 'failure_code' => 'http_503')
    expect(check.candidates.size).to eq(1)
  end
end
