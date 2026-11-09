require 'rails_helper'

RSpec.describe Payloads::StageUpload do
  self.use_transactional_tests = false

  let(:root) { Rails.application.config.x.storage.fetch(:payload) }

  after { FileUtils.rm_rf(root.join('staging')) }

  it 'rejects an empty file and cleans its incomplete stage' do
    expect { described_class.call(upload: ebook_upload(bytes: '')) }.to raise_error(described_class::InvalidUpload, /vide/)
    expect(root.glob('staging/*')).to be_empty
  end

  it 'bounds actual streamed bytes rather than trusting the declared size' do
    stub_const('Payloads::StageUpload::MAX_BYTES', 8)

    expect { described_class.call(upload: ebook_upload) }.to raise_error(described_class::InvalidUpload, /limite/)
    expect(root.glob('staging/*')).to be_empty
  end

  it 'rejects traversal and unsupported filenames' do
    [ '../book.epub', 'dir\book.pdf', "line\nbreak.mobi", 'book.zip' ].each do |name|
      expect { described_class.call(upload: ebook_upload(name)) }.to raise_error(described_class::InvalidUpload)
    end
    expect { described_class.call(upload: 'a host path') }.to raise_error(described_class::InvalidUpload)
  end

  it 'rejects a staging symlink without writing through it' do
    File.symlink(Rails.application.config.x.storage.fetch(:scratch), root.join('staging'))

    expect { described_class.call(upload: ebook_upload) }.to raise_error(described_class::StorageFailure, /symbolique/)
    expect(Rails.application.config.x.storage.fetch(:scratch).glob('*.epub')).to be_empty
  end

  it 'hashes and copies without holding an application write transaction' do
    upload = ebook_upload
    allow(upload).to receive(:read).and_wrap_original do |original, *arguments|
      expect(ApplicationRecord.connection.transaction_open?).to be(false)
      original.call(*arguments)
    end

    staged = described_class.call(upload: upload)
    expect(staged.size).to eq(22)
  end

  it 'preserves every byte value across streamed chunk boundaries' do
    bytes = (0..255).to_a.pack('C*') * ((described_class::CHUNK_BYTES / 256) + 1)
    staged = described_class.call(upload: ebook_upload(bytes: bytes))

    expect(staged.path.binread).to eq(bytes)
    expect(staged.size).to eq(bytes.bytesize)
    expect(staged.sha256).to eq(Digest::SHA256.hexdigest(bytes))
  end
end
