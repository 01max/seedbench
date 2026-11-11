require 'rails_helper'

RSpec.describe Providers::C411::Publications do
  let(:client) { described_class.new(create_connection) }
  let(:info_hash) { 'a' * 40 }

  it 'submits the reviewed release and attachments with standard multipart fields' do
    response = { success: true, data: { id: 42, infoHash: info_hash, status: 'approved' } }
    request = stub_request(:post, 'https://c411.org/api/torrents')
      .with(headers: { 'Authorization' => 'Bearer synthetic-private-credential', 'Content-Type' => %r{multipart/form-data} })
      .to_return(body: response.to_json)

    receipt = client.submit(fields: { 'descriptionFormat' => 'standard', 'title' => 'Livre' }, torrent: 'bytes-torrent', nfo: 'bytes-nfo', name: 'Livre')

    expect(receipt.to_h).to eq(id: 42, info_hash: info_hash, status: 'approved')
    expect(request).to have_been_requested.once
  end
end
