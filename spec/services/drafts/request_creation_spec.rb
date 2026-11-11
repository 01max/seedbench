require 'rails_helper'

RSpec.describe Drafts::Request do
  self.use_transactional_tests = false
  around { |example| with_preparation_storage { with_committed_cover_database { example.run } } }

  let(:remote) { {} }

  before do
    stub_cover_hosting
    stub_draft_categories
    stub_request(:get, 'https://c411.org/api/user/drafts/new-draft').to_return { { body: { success: true, data: remote }.to_json } }
  end

  def stub_replacement_draft(remote)
    stub_request(:post, 'https://c411.org/api/user/drafts').to_return do |request|
      apply_draft_body(remote, JSON.parse(request.body))['id'] = 'replacement'
      { body: { success: true, data: { id: 'replacement' } }.to_json }
    end
    stub_request(:get, 'https://c411.org/api/user/drafts/replacement').to_return { { body: { success: true, data: remote }.to_json } }
  end

  def prepare_cover_review(release)
    first = run_draft(release)
    expect(first.error_code).to eq('review_required_for_write')
    expect(WebMock).not_to have_requested(:post, 'https://c411.org/api/user/drafts')
    accept_draft_cover(release)
  end

  it 'hosts within the explicit action, pauses for URL review, then creates the exact prepared draft once' do
    release = prepared_draft_payload
    prepare_cover_review(release)
    sent = stub_request(:post, 'https://c411.org/api/user/drafts').to_return do |request|
      apply_draft_body(remote, JSON.parse(request.body))['id'] = 'new-draft'
      { body: { success: true, data: { id: 'new-draft' } }.to_json }
    end
    write = run_draft(release)
    expect(write.state).to eq('accepted')
    expect(write.body).to include('categoryId' => 22, 'subcategoryId' => 114, 'options' => { '112' => 1190, '113' => 1197 })
    expect(Base64.strict_decode64(write.body['torrentFileData'])).to eq(Preparation::Paths.new.path(release.preparation_revisions.last.torrent_locator, kind: :state).binread)
    expect(sent).to have_been_requested.once
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
  end

  it 'retains an uncertain create and requires confirmed matching identity instead of retrying' do
    release = prepared_draft_payload
    prepare_cover_review(release)
    sent = stub_request(:post, 'https://c411.org/api/user/drafts').to_timeout
    write = run_draft(release)
    apply_draft_body(remote, write.body)['id'] = 'new-draft'
    expect { Drafts::Reconcile.call(release_id: release.id, write_id: write.id, remote_id: 'new-draft') }.to raise_error(Drafts::Failure)
    Drafts::Reconcile.call(release_id: release.id, write_id: write.id, remote_id: 'new-draft', confirmed: true)
    expect(release.reload.draft_link.remote_id).to eq('new-draft')
    expect(sent).to have_been_requested.once
    expect(release.publication_state).to eq('unpublished')
  end

  it 'stops against an actual full-slot listing without creating or deleting a draft' do
    release = prepared_draft_payload
    prepare_cover_review(release)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [], count: 15, maxAllowed: 15 }.to_json)
    expect(run_draft(release).error_code).to eq('slots_full')
    expect(WebMock).not_to have_requested(:post, 'https://c411.org/api/user/drafts')
    expect(WebMock).not_to have_requested(:delete, /c411/)
  end

  it 'requires confirmed recreation after deletion and retains both remote identities' do
    release = prepared_draft_payload
    prepare_cover_review(release)
    stub_request(:post, 'https://c411.org/api/user/drafts').to_return do |request|
      apply_draft_body(remote, JSON.parse(request.body))['id'] = 'new-draft'
      { body: { success: true, data: { id: 'new-draft' } }.to_json }
    end
    run_draft(release)
    stub_request(:get, 'https://c411.org/api/user/drafts/new-draft').to_return(status: 404)
    Drafts::Sync.call(link: release.reload.draft_link)
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision) }.to raise_error(Drafts::Failure)
    stub_replacement_draft(remote)
    operation = described_class.call(release_id: release.id, expected_revision: release.input_revision, recreate_confirmed: true)
    Workflows::Execute.call(operation_id: operation.id)
    expect(release.reload.draft_link.remote_id).to eq('replacement')
    expect(release.remote_snapshots.pluck(:remote_id).uniq).to contain_exactly('new-draft', 'replacement')
  end

  it 'reconciles an uncertain creation already imported as a shell without duplicating its identity' do
    release = prepared_draft_payload
    prepare_cover_review(release)
    sent = stub_request(:post, 'https://c411.org/api/user/drafts').to_timeout
    write = run_draft(release)
    apply_draft_body(remote, write.body)['id'] = 'new-draft'
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [ { id: 'new-draft' } ], count: 1, maxAllowed: 15 }.to_json)
    Drafts::Import.call(connection: write.provider_connection)
    shell_id = DraftLink.sole.release_id
    Drafts::Reconcile.call(release_id: release.id, write_id: write.id, remote_id: 'new-draft', confirmed: true)
    expect(DraftLink.sole.release_id).to eq(release.id)
    expect(Release.find(shell_id).content_revisions).not_to be_empty
    expect(sent).to have_been_requested.once
  end

  it 'preserves unrelated remote option selections when updating a linked ebook' do
    release = prepared_draft_payload
    prepare_cover_review(release)
    stub_request(:post, 'https://c411.org/api/user/drafts').to_return do |request|
      apply_draft_body(remote, JSON.parse(request.body))['id'] = 'new-draft'
      { body: { success: true, data: { id: 'new-draft' } }.to_json }
    end
    run_draft(release)
    remote['options']['114'] = [ 2001, 2002 ]
    stub_request(:patch, 'https://c411.org/api/user/drafts/new-draft').to_return do |request|
      apply_draft_body(remote, JSON.parse(request.body))
      { body: { success: true }.to_json }
    end
    expect(run_draft(release).body['options']).to include('114' => [ 2001, 2002 ])
  end
end
