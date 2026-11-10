require 'open3'

module CoverFixtures
  def with_committed_cover_database
    configuration = ApplicationRecord.connection_db_config
    ApplicationRecord.establish_connection(adapter: 'sqlite3', database: ':memory:')
    ApplicationRecord.connection_pool.with_connection do |connection|
      connection.raw_connection.execute_batch(Rails.root.join('db/structure.sql').read)
    end
    yield
  ensure
    ApplicationRecord.establish_connection(configuration)
  end

  def cover_write_operation(release, kind: 'draft_write', parameters: {})
    release.reload.workflow_operations.create!(kind: kind, request_key: SecureRandom.uuid, effect: 'remote', input_revision: release.input_revision,
      state: 'running', attempt_token: SecureRandom.uuid, lease_expires_at: 5.minutes.from_now, attempts: 1, parameters: parameters)
  end

  def configure_cover_host(release)
    connection = Settings::CreateConnection.call(role: 'image_host', label: 'Synthetic image host', identity_key: SecureRandom.uuid,
      credentials: { api_key: 'a' * 32 })
    Settings::AssignConnection.call(release_id: release.id, role: 'image_host', connection_id: connection.id, expected_revision: release.reload.input_revision)
    connection
  end

  def stub_cover_hosting(bytes: cover_bytes(width: 512, height: 768))
    %w[postimg.cc i.postimg.cc].each { |host| allow(Resolv).to receive(:getaddresses).with(host).and_return([ '93.184.216.34' ]) }
    stub_request(:post, 'https://api.postimage.org/1/upload').to_return(body: '{"url":"https://postimg.cc/abc123"}')
    stub_request(:get, 'https://postimg.cc/abc123').to_return(body: '<input id="direct" value="https://i.postimg.cc/abc123/cover.png">')
    stub_request(:get, 'https://i.postimg.cc/abc123/cover.png').to_return(body: bytes, headers: { 'Content-Type' => 'image/png' })
  end

  def cover_bytes(width: 600, height: 900, color: 'navy')
    code = "from PIL import Image;import sys;Image.new('RGB',(int(sys.argv[1]),int(sys.argv[2])),sys.argv[3]).save(sys.stdout.buffer,format='PNG')"
    bytes, status = Open3.capture2('python3', '-c', code, width.to_s, height.to_s, color)
    raise 'Synthetic image generation failed' unless status.success?

    bytes.b
  end

  def cover_review
    { edition_match: true, quality_reviewed: true, note: 'Édition et netteté comparées manuellement.' }
  end

  def choose_manual_cover(release, bytes: cover_bytes, review: cover_review)
    Covers::Select.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: 'manual',
      attributes: { image: ebook_upload('cover.png', bytes: bytes) }, review: review)
  end
end

RSpec.configure { |config| config.include CoverFixtures }
