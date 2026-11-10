require 'rails_helper'

RSpec.describe Preparation::Move do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:payload) { release.payload_revisions.sole }
  let(:operation) { preparation_operation(release) }
  let(:names) { Providers::C411::EbookNaming.from_release(name: operation.parameters.fetch('release_name'), format: 'epub') }
  let(:paths) { Preparation::Paths.new }

  it 'renames one unchanged inode, preserves original metadata and grants the shared group read access' do
    original = paths.path(payload.locator)
    stat = original.stat
    move = described_class.call(operation: operation, names: names)
    canonical = paths.path(payload.reload.locator)
    expect(original).not_to exist
    expect([ canonical.stat.dev, canonical.stat.ino ]).to eq([ stat.dev, stat.ino ])
    expect(Digest::SHA256.file(canonical).hexdigest).to eq(payload.sha256)
    expect([ payload.original_filename, canonical.stat.mode & 0o777, move.state ]).to eq([ 'Original.epub', 0o640, 'moved' ])
  end

  it 'recovers a crash after rename before recording the new locator' do
    Preparation::Reserve.call(operation: operation, payload: payload, destination: names.payload)
    original = paths.path(payload.locator)
    Preparation::Rename.call(source: original, destination: paths.path(names.payload, missing: true))
    2.times { described_class.call(operation: operation, names: names) }
    expect(payload.reload.locator).to eq(names.payload)
    expect(paths.root.glob('*.epub').size).to eq(1)
    expect(paths.root.glob('staging/*.epub')).to be_empty
  end

  it 'rejects a substitute with the same bytes but another inode after interruption' do
    move = Preparation::Reserve.call(operation: operation, payload: payload, destination: names.payload)
    source = paths.path(payload.locator)
    paths.root.join(names.payload).binwrite(source.binread)
    source.unlink
    expect { Preparation::Journal.call(move: move) }.to raise_error(Preparation::Failure, /identité/)
    expect(payload.reload.locator).to start_with('staging/')
  end

  it 'reconciles an already moved file even when the release was edited during interruption' do
    move = Preparation::Reserve.call(operation: operation, payload: payload, destination: names.payload)
    Preparation::Rename.call(source: paths.path(payload.locator), destination: paths.path(names.payload, missing: true))
    release.update!(input_revision: 1)
    Preparation::Reconcile.call(operation: operation)
    expect(payload.reload.locator).to eq(names.payload)
    expect(move.reload.state).to eq('completed')
  end

  it 'cancels an obsolete reservation without moving its staged file' do
    move = Preparation::Reserve.call(operation: operation, payload: payload, destination: names.payload)
    release.update!(input_revision: 1)
    Preparation::Reconcile.call(operation: operation)
    expect(move.reload.state).to eq('cancelled')
    expect(paths.path(payload.reload.locator)).to be_file
  end

  it 'blocks expired attempts, changed inputs and published or seeded payloads' do
    operation
    operation.update!(lease_expires_at: 1.minute.ago)
    expect { described_class.call(operation: operation, names: names) }.to raise_error(Preparation::Failure, /interrompue/)
    operation.update!(lease_expires_at: 5.minutes.from_now)
    release.update!(input_revision: 1)
    expect { described_class.call(operation: operation, names: names) }.to raise_error(Releases::RevisionConflict)
    release.update!(input_revision: 0, publication_state: 'published')
    expect { described_class.call(operation: operation, names: names) }.to raise_error(Preparation::Failure, /publié/)
    expect(paths.path(payload.reload.locator)).to be_file
  end
end
