require 'rails_helper'

RSpec.describe Providers::C411::Drafts do
  let(:client) { described_class.new(create_connection) }

  it 'serializes explicit CRUD with bearer authentication and no retries' do
    stub_draft_account
    created = stub_request(:post, 'https://c411.org/api/user/drafts').with(body: { title: 'Test' }.to_json,
      headers: { 'Authorization' => 'Bearer synthetic-private-credential' }).to_return(body: { success: true, data: { id: 42 } }.to_json)
    changed = stub_request(:patch, 'https://c411.org/api/user/drafts/42').with(body: { description: 'Changed' }.to_json).to_return(body: { success: true }.to_json)
    deleted = stub_request(:delete, 'https://c411.org/api/user/drafts/42').to_return(body: { success: true }.to_json)
    expect(client.list.maximum).to eq(15)
    expect(client.read('draft-1')['title']).to eq('Livre distant')
    expect(client.create(title: 'Test')).to eq('42')
    client.update('42', description: 'Changed')
    client.delete('42')
    expect([ created, changed, deleted ]).to all(have_been_requested.once)
  end

  it 'rejects failed envelopes, mismatched identities and redirects without leaking response bodies' do
    [ { success: false }, { success: true, data: { id: 'other' } } ].each do |data|
      stub_request(:get, 'https://c411.org/api/user/drafts/42').to_return(body: data.to_json)
      expect { client.read('42') }.to raise_error(Providers::Failure, /invalide/)
    end
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 302, body: 'private response')
    expect { client.list }.to raise_error(Providers::Failure, /HTTP 302/)
  end
end
