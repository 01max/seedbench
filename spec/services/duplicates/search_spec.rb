require 'rails_helper'

RSpec.describe Duplicates::Search do
  let(:release) { reviewed_content_release }

  before { configure_duplicate_search(release) }

  it 'searches title variants, author and ISBN, retaining evidence but no credential-bearing URLs' do
    stub_duplicate_search
    check = search_duplicates(release)
    expect(check.query).to include('status' => 'complete', 'queries' => [ 'Synthetic book', 'Synthetic book Test author', '9780306406157' ])
    expect(check.candidates.sole).to include('format' => [ 'EPUB' ], 'description' => 'Édition numérique de test.', 'url' => "https://c411.org/torrents/#{'e' * 40}")
    expect(check.to_json).not_to include('synthetic-search-key', '/api/download')
    expect(release.workflow_operations.last.state).to eq('succeeded')
    expect(WebMock).not_to have_requested(:post, %r{c411.org})
  end

  it 'keeps partial results and a named failure when another query fails' do
    stub_duplicate_search
    stub_request(:get, %r{c411.org/api\?}).with(query: hash_including('q' => '9780306406157')).to_return(status: 503)
    check = search_duplicates(release)
    expect(check.query).to include('status' => 'unavailable', 'failure_code' => 'http_503')
    expect(check.candidates.size).to eq(1)
  end

  it 'rejects non-feed, entity-bearing and malformed responses instead of reporting clear' do
    [ '<html>Login</html>', '<!DOCTYPE rss [<!ENTITY test SYSTEM "file:///etc/passwd">]><rss/>', '<rss><channel>' ].each do |body|
      stub_duplicate_search(body: body)
      expect(search_duplicates(release).query['status']).to eq('unavailable')
    end
  end

  it 'marks unidentifiable results incomplete and treats an empty valid feed as complete' do
    stub_duplicate_search(body: '<rss><channel><item><title>Unknown edition</title></item></channel></rss>')
    expect(search_duplicates(release).query['status']).to eq('incomplete')
    stub_duplicate_search(body: '<rss><channel/></rss>')
    expect(search_duplicates(release).query['status']).to eq('complete')
  end

  it 'pages bounded results and refuses to declare a truncated feed complete' do
    body = duplicate_feed.sub('</item>', '</item>' + (duplicate_feed[/<item>.*?<\/item>/m] * 99))
    stub_duplicate_search(body: body)
    check = search_duplicates(release)
    expect(check.query['status']).to eq('incomplete')
    expect(WebMock).to have_requested(:get, %r{c411.org/api\?}).with(query: hash_including('offset' => '100')).times(3)
  end

  it 'discards results when reviewed inputs change while the search is running' do
    operation = Duplicates::Request.call(release_id: release.id, expected_revision: release.input_revision)
    token = Workflows::Claim.call(operation_id: operation.id)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { edition: 'Another edition' })
    Workflows::Complete.call(operation_id: operation.id, attempt_token: token, result: { 'status' => 'complete', 'candidates' => [] }, apply: Duplicates::Record)
    expect(operation.reload.state).to eq('stale')
    expect(release.duplicate_checks.count).to eq(1)
  end

  it 'binds current results to material facts and connection while allowing prose edits' do
    stub_duplicate_search
    search_duplicates(release)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { notes: 'New human prose' })
    expect(Duplicates::Workspace.call(release: release.reload).current).to be(true)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { edition: 'New edition' })
    expect(Duplicates::Workspace.call(release: release.reload).current).to be(false)
  end
end
