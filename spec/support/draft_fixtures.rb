module DraftFixtures
  def draft_data(id = 'draft-1', description: 'Description distante conservée.')
    { 'id' => id, 'name' => 'Livre distant-NOTAG', 'title' => 'Livre distant', 'description' => description,
      'updatedAt' => '2026-11-10T12:00:00Z', 'categoryId' => 2, 'subcategoryId' => 14, 'options' => {} }
  end

  def stub_draft_account(data = draft_data)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [ { id: data['id'] } ], count: 1, maxAllowed: 15 }.to_json)
    stub_request(:get, "https://c411.org/api/user/drafts/#{data['id']}").to_return(body: { success: true, data: data }.to_json)
  end

  def imported_draft
    connection = create_connection
    stub_draft_account
    Drafts::Import.call(connection: connection)
    DraftLink.sole.release
  end
end

RSpec.configure { |config| config.include DraftFixtures }
