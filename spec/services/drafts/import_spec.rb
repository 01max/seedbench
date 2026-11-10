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
end
