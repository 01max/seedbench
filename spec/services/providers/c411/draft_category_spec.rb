require 'rails_helper'

RSpec.describe Providers::C411::DraftCategory do
  it 'rejects malformed nested reference data instead of constructing an unverified category or request path' do
    connection = create_connection
    [ { id: '../other', slug: 'ebook', subcategories: [] }, { id: 2, slug: 'ebook', subcategories: 'invalid' } ].each do |category|
      stub_request(:get, 'https://c411.org/api/categories').to_return(body: { data: [ category ] }.to_json)
      expect { described_class.call(connection: connection, format: 'epub') }.to raise_error(Drafts::Failure, /catégories ou options/)
    end
    expect(WebMock).not_to have_requested(:post, /c411/)
  end
end
