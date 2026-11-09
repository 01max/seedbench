require 'rails_helper'

RSpec.describe Torrents::Bencode do
  it 'round-trips binary pieces, dictionaries, lists and integers canonically' do
    data = { 'info' => { 'pieces' => "\x00\xff".b, 'length' => 42 }, 'list' => [ -1, 0, '' ] }
    expect(described_class.decode(described_class.encode(data))).to eq(data)
  end

  it 'rejects truncation, trailing bytes, duplicate keys and noncanonical values' do
    [ 'd1:ai1e1:ai2ee', 'd1:bi1e1:ai2ee', 'i01e', 'i-0e', '3:ab', 'leX', 'l', 'd', 'garbage' ].each do |bytes|
      expect { described_class.decode(bytes) }.to raise_error(described_class::Invalid)
    end
  end

  it 'bounds input bytes, depth and nodes' do
    expect { described_class.decode('a' * (described_class::MAX_BYTES + 1)) }.to raise_error(described_class::Invalid)
    expect { described_class.decode(('l' * 20) + ('e' * 20)) }.to raise_error(described_class::Invalid)
    expect { described_class.decode('l' + ('0:' * 1025) + 'e') }.to raise_error(described_class::Invalid)
  end
end
