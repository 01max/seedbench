require 'rails_helper'

RSpec.describe Covers::Host do
  self.use_transactional_tests = false

  around { |example| with_preparation_storage { with_committed_cover_database { example.run } } }

  let(:release) { staged_preparation_release }
  let(:cover) { choose_manual_cover(release) }
  let(:operation) { cover_write_operation(release) }

  def host
    described_class.call(operation_id: operation.id, attempt_token: operation.attempt_token)
  end

  before do
    cover
    configure_cover_host(release)
    stub_cover_hosting
  end

  it 'hosts only an explicit approved operation and measures the actual smaller direct image' do
    hosting = host
    expect([ hosting.width, hosting.height ]).to eq([ 512, 768 ])
    expect(hosting.verification).to include('source_sha256' => cover.edition_evidence['sha256'], 'mean_pixel_difference' => 0.0)
    expect(release.cover_uploads.sole.state).to eq('verified')
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
    expect(release.remote_snapshots).to be_empty
  end

  it 'reverifies current hosted bytes on reuse without uploading again' do
    first = host
    second = host
    expect(second.cover_revision_id).to eq(first.cover_revision_id)
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
    expect(WebMock).to have_requested(:get, 'https://i.postimg.cc/abc123/cover.png').twice
    expect(release.cover_hostings.count).to eq(2)
  end

  it 'refuses wrong-kind, expired and stale attempts before making an upload' do
    other = cover_write_operation(release, kind: 'inspection')
    expect { described_class.call(operation_id: other.id, attempt_token: other.attempt_token) }.to raise_error(Covers::Failure, /réservé/)
    operation.update!(lease_expires_at: 1.second.ago)
    expect { host }.to raise_error(Covers::Failure)
    expect(WebMock).not_to have_requested(:post, 'https://api.postimage.org/1/upload')
  end

  it 'does no network I/O while a local write transaction is open' do
    operation
    ApplicationRecord.transaction { expect { host }.to raise_error(Covers::Failure, /transaction/) }
    expect(WebMock).not_to have_requested(:post, 'https://api.postimage.org/1/upload')
  end

  it 'retains the receipt and retries verification without another upload after a bad direct link' do
    stub_request(:get, 'https://i.postimg.cc/abc123/cover.png').to_return(body: '<html>Not an image</html>', headers: { 'Content-Type' => 'text/html' })
    expect { host }.to raise_error(Covers::Failure)
    expect(release.cover_uploads.sole.direct_url).to eq('https://i.postimg.cc/abc123/cover.png')
    stub_cover_hosting
    expect(host.media_type).to eq('image/png')
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
  end

  it 'blocks a wrong edition image and invalidates hosted eligibility after selection or fact changes' do
    stub_cover_hosting(bytes: cover_bytes(color: 'red'))
    expect { host }.to raise_error(Covers::Failure, /correspond pas/)
    expect(release.cover_hostings).to be_empty
    choose_manual_cover(release, bytes: cover_bytes(color: 'green'))
    expect { host }.to raise_error(Covers::Failure, /ont changé/)
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
  end

  it 'does not repeat an upload after an ambiguous timeout, even from a new write operation' do
    stub_request(:post, 'https://api.postimage.org/1/upload').to_timeout
    expect { host }.to raise_error(Providers::Failure)
    expect(release.cover_uploads.sole.state).to eq('outcome_unknown')
    other = cover_write_operation(release)
    expect { described_class.call(operation_id: other.id, attempt_token: other.attempt_token) }.to raise_error(Covers::Failure, /peut-être/)
    expect(WebMock).to have_requested(:post, 'https://api.postimage.org/1/upload').once
  end
end
