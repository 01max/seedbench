module DuplicateFixtures
  def configure_duplicate_search(release)
    stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [] }.to_json)
    connection = release.provider_assignments.find_by!(role: 'publishing').provider_connection
    connection.update!(endpoint: 'https://c411.org', credentials: { 'api_key' => 'synthetic-search-key' })
    connection
  end

  def duplicate_feed(title: 'Synthetic book Test author EPUB', hash: 'e' * 40, description: 'Édition numérique de test.', total: nil)
    total_xml = total ? "<response total=\"#{total}\"/>" : ''
    <<~XML
      <rss xmlns:t="http://torznab.com/schemas/2015/feed"><channel>#{total_xml}<item>
      <title>#{CGI.escapeHTML(title)}</title><description>#{CGI.escapeHTML(description)}</description>
      <enclosure url="https://c411.org/api/download?apikey=synthetic-search-key"/>
      <t:attr name="infohash" value="#{hash}"/><t:attr name="size" value="2048"/>
      </item></channel></rss>
    XML
  end

  def stub_duplicate_search(body: duplicate_feed)
    stub_request(:get, %r{\Ahttps://c411.org/api\?}).to_return(body: body)
  end

  def search_duplicates(release)
    operation = Duplicates::Request.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Workflows::Execute.call(operation_id: operation.id)
    release.duplicate_checks.order(:id).last
  end
end

RSpec.configure { |config| config.include DuplicateFixtures }
