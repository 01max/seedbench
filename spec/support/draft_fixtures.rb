module DraftFixtures
  def draft_data(id = 'draft-1', description: 'Description distante conservée.')
    { 'id' => id, 'name' => 'Livre distant-NOTAG', 'title' => 'Livre distant', 'description' => description,
      'updatedAt' => '2026-11-10T12:00:00Z', 'categoryId' => 2, 'subcategoryId' => 14, 'options' => {} }
  end

  def stub_draft_account(data = draft_data)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [ { id: data['id'] } ], count: 1, maxAllowed: 15 }.to_json)
    stub_request(:get, "https://c411.org/api/user/drafts/#{data['id']}").to_return(body: { success: true, data: data }.to_json)
  end

  def apply_draft_body(remote, body)
    remote.merge!(body.except('torrentFileName', 'torrentFileData', 'nfoFileName', 'nfoFileData'))
    %w[torrent nfo].each do |kind|
      next unless body.key?("#{kind}FileData")
      remote["#{kind}File"] = body["#{kind}FileData"] ? { 'name' => body["#{kind}FileName"], 'data' => body["#{kind}FileData"] } : nil
    end
    remote
  end

  def imported_draft
    connection = create_connection
    stub_draft_account
    Drafts::Import.call(connection: connection)
    DraftLink.sole.release
  end
end

RSpec.configure { |config| config.include DraftFixtures }

module DraftPayloadFixtures
  def prepared_draft_payload
    release = staged_preparation_release
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: {
      title: 'Synthetic draft book', author: 'Synthetic author', language: 'fr', isbn_kind: 'not_applicable',
      publisher: 'Synthetic publisher', publication_year: '2024', presentation: 'Présentation synthétique relue pour le brouillon.' })
    connection = create_connection
    Settings::AssignConnection.call(release_id: release.id, role: 'publishing', connection_id: connection.id, expected_revision: release.reload.input_revision)
    configure_cover_host(release)
    choose_manual_cover(release)
    Preparation::SuggestName.call(release: release.reload)
    operation = Preparation::Request.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Workflows::Execute.call(operation_id: operation.id)
    %w[bbcode nfo].each do |kind|
      proposal = Content::Propose.call(release_id: release.id, expected_revision: release.reload.input_revision, kind: kind)
      Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
    end
    release.reload
  end

  def stub_draft_categories
    categories = [ { id: 22, slug: 'ebook', subcategories: [ { id: 114, slug: 'livres' } ] } ]
    options = [ { id: 112, slug: 'format-ebook', isRequired: true, values: [ { id: 1190, slug: 'epub' } ] },
      { id: 113, slug: 'langue-bd', isRequired: true, values: [ { id: 1197, slug: 'francais' } ] } ]
    stub_request(:get, 'https://c411.org/api/categories').to_return(body: { data: categories }.to_json)
    stub_request(:get, 'https://c411.org/api/categories/114/options').to_return(body: { data: options }.to_json)
  end

  def run_draft(release)
    operation = Drafts::Request.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Workflows::Execute.call(operation_id: operation.id)
    release.draft_writes.order(:id).last
  end

  def accept_draft_cover(release)
    proposal = Content::CoverPatch.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
  end
end

RSpec.configure { |config| config.include DraftPayloadFixtures }
