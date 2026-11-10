module ContentFixtures
  def add_hosted_content_cover(release, width:, height:, hosted_width: width, hosted_height: height)
    cover = release.cover_revisions.create!(payload_revision: release.payload_revisions.sole,
      number: release.cover_revisions.maximum(:number).to_i + 1, source_kind: 'embedded',
      source_locator: 'covers/small.png', width: width, height: height, edition_evidence: synthetic_cover_evidence(release))
    assignment = release.provider_assignments.find_by!(role: 'image_host')
    release.cover_hostings.create!(cover_revision: cover, provider_connection_id: assignment.provider_connection_id,
      direct_url: cover.number == 1 ? 'https://images.invalid/synthetic.png' : "https://images.invalid/cover-#{cover.id}.png", media_type: 'image/png',
      width: hosted_width, height: hosted_height, verified_at: Time.current, verification: synthetic_cover_proof(cover))
  end

  def reviewed_content_release
    release = build_release_graph(include_cover: false)
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
    add_hosted_content_cover(release, width: 600, height: 900)
    release
  end
end

RSpec.configure { |config| config.include ContentFixtures }
