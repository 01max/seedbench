require 'rails_helper'

RSpec.describe Drafts::Import do
  it 'imports an editable shell once without linking a similar upload or writing remotely' do
    upload = Releases::Create.call(title: 'Livre distant')
    connection = create_connection
    stub_draft_account
    2.times { described_class.call(connection: connection) }
    shell = DraftLink.sole.release

    expect(shell.id).not_to eq(upload.id)
    expect(shell.payload_revisions).to be_empty
    expect(Releases::EditorValues.call(release: shell)).to include('bbcode' => 'Description distante conservée.')
    expect(shell.provider_assignments.find_by!(role: 'publishing').provider_connection_id).to eq(connection.id)
    expect(WebMock).not_to have_requested(:post, /c411/)
  end

  it 'refuses malformed remote identifiers and bounded content without creating a shell' do
    connection = create_connection
    stub_draft_account(draft_data('../escape'))
    expect { described_class.call(connection: connection) }.to raise_error(Providers::Failure)
    expect(DraftLink.count).to eq(0)
  end

  it 'imports an incomplete blank-title draft without fabricating edition facts' do
    connection = create_connection
    stub_draft_account(draft_data.merge('title' => nil, 'name' => ''))
    described_class.call(connection: connection)
    shell = DraftLink.sole.release
    expect(Drafts::Content.local(shell)).to include('title' => '', 'name' => '')
    expect(shell.reviewed_facts).to be_empty
  end

  it 'imports healthy drafts even when another draft detail cannot be read' do
    connection = create_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [ { id: 'bad' }, { id: 'good' } ] }.to_json)
    stub_request(:get, 'https://c411.org/api/user/drafts/bad').to_return(status: 503)
    stub_request(:get, 'https://c411.org/api/user/drafts/good').to_return(body: { success: true, data: draft_data('good') }.to_json)
    expect { described_class.call(connection: connection) }.to raise_error(Providers::Failure, /HTTP 503/)
    expect(DraftLink.sole.remote_id).to eq('good')
    expect(WebMock).not_to have_requested(:post, /c411/)
  end

  it 'captures the source account at creation even when another C411 connection is the default' do
    default = create_connection(identity: 'default-account')
    ProviderDefault.create!(role: 'publishing', provider_connection: default)
    source = create_connection(identity: 'source-account')
    stub_draft_account
    described_class.call(connection: source)
    assignment = DraftLink.sole.release.provider_assignments.find_by!(role: 'publishing')
    expect(assignment.provider_connection_id).to eq(source.id)
    expect(ProviderDefault.sole.provider_connection_id).to eq(default.id)
  end
end
