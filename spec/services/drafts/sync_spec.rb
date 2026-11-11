require 'rails_helper'

RSpec.describe Drafts::Sync do
  let(:release) { imported_draft }

  def sync(data)
    stub_draft_account(data)
    described_class.call(link: release.draft_link)
    release.reload
  end

  def edit(body)
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: body })
    release.reload
  end

  it 'adopts remote-only changes and advances the base with append-only local content' do
    original = release.content_revisions.last
    sync(draft_data(description: 'Remote-only edit'))
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Remote-only edit')
    expect(original.reload.body).to eq('Description distante conservée.')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Remote-only edit')
    expect(WebMock).not_to have_requested(:patch, /c411/)
  end

  it 'retains both copies and the original base when both sides change' do
    edit('Local changed')
    sync(draft_data(description: 'Remote changed'))
    expect(release.draft_state).to eq('conflicted')
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Local changed')
    expect(release.remote_snapshots.last.remote_content['description']).to eq('Remote changed')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Description distante conservée.')
  end

  it 'retains unsent local edits and converges when the remote becomes identical' do
    edit('Local changed')
    sync(draft_data)
    expect(Releases::EditorValues.call(release: release)['bbcode']).to eq('Local changed')
    sync(draft_data(description: 'Local changed'))
    expect(release.draft_state).to eq('synced')
    expect(release.remote_snapshots.last.base_content['description']).to eq('Local changed')
  end

  it 'does not turn a failed account refresh into an implicit mutation' do
    connection = release.draft_link.provider_connection
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 503)
    expect(Drafts::Refresh.call(connection: connection)).to contain_exactly(include('HTTP 503'))
    expect(release.reload.draft_state).to eq('synced')
    expect(WebMock).not_to have_requested(:delete, /c411/)
  end

  it 'reports a failed draft read and still refreshes the remaining links' do
    connection = release.draft_link.provider_connection
    second = draft_data('draft-2')
    stub_draft_account(second)
    Drafts::Import.call(connection: connection)
    healthy = connection.draft_links.find_by!(remote_id: 'draft-2').release
    stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return(status: 503)
    stub_draft_account(second.merge('description' => 'New remote copy'))

    expect(Drafts::Refresh.call(connection: connection)).to contain_exactly(include('draft-1', 'HTTP 503'))
    expect(Drafts::Content.local(healthy.reload)['description']).to eq('New remote copy')
  end

  it 'continues refreshing linked drafts when a new draft cannot be imported' do
    connection = release.draft_link.provider_connection
    stub_draft_account(draft_data(description: 'Remote edit to an existing draft'))
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [ { id: 'unreadable' } ] }.to_json)
    stub_request(:get, 'https://c411.org/api/user/drafts/unreadable').to_return(status: 503)

    expect(Drafts::Refresh.call(connection: connection)).to contain_exactly(include('unreadable', 'HTTP 503'))
    expect(Drafts::Content.local(release.reload)['description']).to eq('Remote edit to an existing draft')
  end

  it 'rejects an older read completing after a newer observation without reverting its adopted text' do
    link = release.draft_link
    stub_request(:get, 'https://c411.org/api/user/drafts/draft-1').to_return do
      Drafts::Observe.call(link: link, content: Drafts::Content.remote(draft_data(description: 'Newer observed text')), remote_revision: 'newer')
      { body: { success: true, data: draft_data(description: 'Older network response') }.to_json }
    end
    expect { described_class.call(link: link) }.to raise_error(Drafts::Failure, /autre lecture/)
    expect(Drafts::Content.local(release.reload)['description']).to eq('Newer observed text')
  end

  it 'adopts remote-only title edits as content without approving new edition facts' do
    linked = reviewed_content_release
    connection = linked.provider_assignments.find_by!(role: 'publishing').provider_connection
    link = DraftLink.create!(release: linked, provider_connection: connection, remote_id: 'linked-draft')
    base = Drafts::Content.local(linked)
    linked.remote_snapshots.create!(provider_connection: connection, kind: 'draft', remote_id: link.remote_id,
      local_revision: linked.input_revision, base_content: base, remote_content: base, observed_at: Time.current)
    facts = linked.reviewed_facts.pluck(:id)
    Drafts::Observe.call(link: link, content: base.merge('title' => 'Unreviewed remote title'), remote_revision: 'changed')
    expect(linked.reload.title).to eq('Unreviewed remote title')
    expect(linked.reviewed_facts.pluck(:id)).to eq(facts)
    expect(linked.release_events.find_by!(name: 'release.revised', input_revision: linked.input_revision).actor).to eq('system')
  end
end
