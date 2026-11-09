require 'rails_helper'

RSpec.describe Preparation::Preflight do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:payload) { release.payload_revisions.sole }
  let(:root) { Rails.application.config.x.storage.fetch(:payload) }

  it 'proves rename access without changing the original inode or retaining probe files' do
    result = described_class.call(payload: payload, destination: 'Book-NOTAG.epub')
    expect(result.identity.ino).to eq(root.join(payload.locator).stat.ino)
    expect(result.source.binread).to eq("Synthetic preparation bytes\n")
    expect(root.glob('.preparation*')).to be_empty
  end

  it 'rejects occupied destinations and changed bytes' do
    root.join('Book.epub').write('Existing bytes')
    expect { described_class.call(payload: payload, destination: 'Book.epub') }.to raise_error(Preparation::Failure, /existe/)
    root.join(payload.locator).write('Different bytes')
    expect { described_class.call(payload: payload, destination: 'Free.epub') }.to raise_error(Preparation::Failure, /identité/)
    expect(root.join('Book.epub').read).to eq('Existing bytes')
  end

  it 'rejects traversal, absolute paths and symlink components' do
    release
    root.join('alias').make_symlink(root.join('staging'))
    [ '../escape.epub', '/outside.epub', 'alias/book.epub', 'bad\\name.epub' ].each do |destination|
      expect { described_class.call(payload: payload, destination: destination) }.to raise_error(Preparation::Failure)
    end
  end

  it 'rejects a symlink source and a mount on a different filesystem' do
    original = root.join(payload.locator)
    original.rename(root.join('original.epub'))
    original.make_symlink(root.join('original.epub'))
    expect { described_class.call(payload: payload, destination: 'Book.epub') }.to raise_error(Preparation::Failure)
    expect { Preparation::Rename.call(source: root.join('original.epub'), destination: Pathname.new('/scratch/cross-device.epub')) }.to raise_error(Preparation::Failure, /système/)
    expect(root.join('original.epub')).to be_file
  end

  it 'reserves a destination uniquely across releases' do
    operation = preparation_operation(release)
    move = Preparation::Reserve.call(operation: operation, payload: payload, destination: 'Book.epub')
    expect(Preparation::Reserve.call(operation: operation, payload: payload, destination: 'Book.epub')).to eq(move)
    other = staged_preparation_release
    expect { Preparation::Reserve.call(operation: preparation_operation(other), payload: other.payload_revisions.sole, destination: 'Book.epub') }.to raise_error(Preparation::Failure, /existe/)
  end

  it 'uses an atomic no-replace rename even if a destination appears after preflight' do
    result = described_class.call(payload: payload, destination: 'Book.epub')
    result.destination.write('Concurrent bytes')
    expect { Preparation::Rename.call(source: result.source, destination: result.destination) }.to raise_error(Preparation::Failure, /existe/)
    expect(result.source).to be_file
    expect(result.destination.read).to eq('Concurrent bytes')
  end
end
