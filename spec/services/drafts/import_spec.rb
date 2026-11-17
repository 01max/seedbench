require 'rails_helper'

RSpec.describe Drafts::Import do
  it 'imports a queue entry once from a draft summary without building an editable release' do
    upload = Releases::Create.call(title: 'Livre distant')
    connection = create_connection
    stub_draft_account
    2.times { described_class.call(connection: connection) }
    shell = DraftLink.sole.release

    expect(shell.id).not_to eq(upload.id)
    expect(shell).to have_attributes(title: 'Livre distant', automatic_ai: false, c411_imported?: true,
      payload_revisions: be_empty, content_revisions: be_empty, remote_snapshots: be_empty, provider_assignments: be_empty)
    expect(WebMock).not_to have_requested(:get, 'https://c411.org/api/user/drafts/draft-1')
    expect(WebMock).not_to have_requested(:post, /c411/)
  end

  it 'refuses malformed remote identifiers without creating a queue entry' do
    connection = create_connection
    stub_draft_account(draft_data('../escape'))
    expect { described_class.call(connection: connection) }.to raise_error(Providers::Failure)
    expect(DraftLink.count).to eq(0)
  end

  it 'uses the draft name when the title is absent and leaves edition facts empty' do
    connection = create_connection
    stub_draft_account(draft_data.merge('title' => nil))
    described_class.call(connection: connection)
    shell = DraftLink.sole.release
    expect(shell.title).to eq('Livre distant-NOTAG')
    expect(shell.reviewed_facts).to be_empty
  end

  it 'retains an archived entry across repeated imports without updating it' do
    connection = create_connection
    stub_draft_account
    described_class.call(connection: connection)
    entry = DraftLink.sole.release
    entry.update!(archived_at: Time.current)
    stub_draft_account(draft_data.merge('title' => 'Edited remotely'))

    expect { described_class.call(connection: connection) }.not_to change(Release, :count)
    expect(entry.reload).to have_attributes(title: 'Livre distant', archived_at?: true)
  end

  it 'captures the source account at creation even when another C411 connection is the default' do
    default = create_connection(identity: 'default-account')
    ProviderDefault.create!(role: 'publishing', provider_connection: default)
    source = create_connection(identity: 'source-account')
    stub_draft_account
    described_class.call(connection: source)
    expect(DraftLink.sole.provider_connection_id).to eq(source.id)
    expect(ProviderDefault.sole.provider_connection_id).to eq(default.id)
  end
end
