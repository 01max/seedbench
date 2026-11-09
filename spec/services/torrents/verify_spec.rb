require 'rails_helper'

RSpec.describe Torrents::Verify do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:operation) { preparation_operation(release) }
  let(:names) { Providers::C411::EbookNaming.from_release(name: operation.parameters.fetch('release_name'), format: 'epub') }
  let(:paths) { Preparation::Paths.new }
  let(:payload) { release.payload_revisions.sole }

  def prepare_torrent
    Preparation::Move.call(operation: operation, names: names)
    Preparation::Torrent.call(operation: operation, names: names)
  end

  def verify(path)
    described_class.call(torrent: path, payload_path: paths.path(payload.reload.locator), payload: payload, name: names.payload)
  end

  it 'creates and independently verifies one private canonical file, reusing the exact artifact on retry' do
    result = prepare_torrent
    second = Preparation::Torrent.call(operation: operation, names: names)
    data = Torrents::Bencode.decode(paths.path(result.locator, kind: :state).binread)
    expect(second).to eq(result)
    expect(data.fetch('info').slice('private', 'name', 'length')).to eq('private' => 1, 'name' => names.payload, 'length' => payload.size_bytes)
    expect(data.fetch('info')).not_to have_key('files')
    expect(result.locator).to end_with('.NOTAG.torrent')
    expect(result.info_hash).to eq(verify(paths.path(result.locator, kind: :state)))
  end

  it 'rejects wrong names, sizes, public and multi-file torrents' do
    result = prepare_torrent
    path = paths.path(result.locator, kind: :state)
    original = Torrents::Bencode.decode(path.binread)
    [ { 'name' => 'Other.epub' }, { 'length' => 123 }, { 'private' => 0 }, { 'files' => [] } ].each do |change|
      data = original.deep_dup
      data.fetch('info').merge!(change)
      path.binwrite(Torrents::Bencode.encode(data))
      expect { verify(path) }.to raise_error(Preparation::Failure, /torrent/)
    end
  end

  it 'checks every piece hash and rejects impossible piece inventories' do
    result = prepare_torrent
    path = paths.path(result.locator, kind: :state)
    data = Torrents::Bencode.decode(path.binread)
    data.fetch('info')['pieces'] = 'x' * 20
    path.binwrite(Torrents::Bencode.encode(data))
    expect { verify(path) }.to raise_error(Preparation::Failure, /morceaux/)
    data.fetch('info')['piece length'] = 3
    path.binwrite(Torrents::Bencode.encode(data))
    expect { verify(path) }.to raise_error(Preparation::Failure, /torrent/)
  end

  it 'rejects changed payload bytes while preserving the file and torrent' do
    result = prepare_torrent
    path = paths.path(result.locator, kind: :state)
    paths.path(payload.reload.locator).binwrite('X' * payload.size_bytes)
    expect { verify(path) }.to raise_error(Preparation::Failure, /identité/)
    expect(path).to be_file
    expect(paths.path(payload.locator)).to be_file
  end
end
