require 'rails_helper'

RSpec.describe CoverUpload do
  let(:release) { build_release_graph }
  let(:operation) { cover_write_operation(release) }
  let(:cover) { release.cover_revisions.sole }
  let(:connection) { release.provider_assignments.find_by!(role: 'image_host').provider_connection }
  let(:upload) do
    described_class.create!(release: release, workflow_operation: operation, cover_revision: cover,
      provider_connection: connection, source_sha256: cover.edition_evidence.fetch('sha256'))
  end

  it 'retains immutable upload identity and once-recorded receipts even through direct SQL' do
    upload.update!(page_url: 'https://postimg.cc/abc', state: 'uploaded')
    sql = ApplicationRecord.connection
    expect { sql.execute("UPDATE cover_uploads SET source_sha256 = '#{'e' * 64}' WHERE id = #{upload.id}") }.to raise_error(ActiveRecord::StatementInvalid)
    expect { sql.execute("UPDATE cover_uploads SET page_url = 'https://postimg.cc/other' WHERE id = #{upload.id}") }.to raise_error(ActiveRecord::StatementInvalid)
    expect { sql.execute("DELETE FROM cover_uploads WHERE id = #{upload.id}") }.to raise_error(ActiveRecord::StatementInvalid)
    expect(upload.reload.page_url).to eq('https://postimg.cc/abc')
  end

  it 'prevents a second pending upload for the same selected source and provider' do
    upload
    other = cover_write_operation(release)
    expect { described_class.create!(release: release, workflow_operation: other, cover_revision: cover,
      provider_connection: connection, source_sha256: cover.edition_evidence.fetch('sha256')) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(release.cover_uploads.count).to eq(1)
  end
end
