module ContentFixtures
  def reviewed_content_release
    release = build_release_graph
    payload = release.payload_revisions.sole
    values = { 'title' => release.title, 'author' => release.author, 'publisher' => 'Synthetic publisher', 'publication_year' => '2024',
      'language' => 'fr', 'isbn' => '9780306406157', 'isbn_kind' => 'digital' }
    values.each do |field, value|
      release.reviewed_facts.create!(payload_revision: payload, field: field, value: value,
        number: release.reviewed_facts.where(field: field).maximum(:number).to_i + 1, actor: 'operator', reviewed_at: Time.current)
    end
    release.evidence_items.create!(payload_revision: payload, evidence_key: 'content-inspection', kind: 'inspection', source: 'Synthetic EPUB parser',
      captured_at: Time.current, input_revision: 0, data: { error: nil, structure: { spine_documents: 5, page_count: nil } })
    release.update!(inspection_state: 'succeeded')
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: { presentation: 'Présentation originale de test.' })
    release.reload
  end
end

RSpec.configure { |config| config.include ContentFixtures }
