module DomainFixtures
  def mark_preparation_current(release)
    payload = release.payload_revisions.sole
    names = Providers::C411::EbookNaming.call(title: release.title, author: release.author, language: 'fr', format: payload.format)
    previous = release.preparation_revisions.order(:number).last
    attributes = previous.attributes.except('id', 'created_at', 'updated_at').merge('number' => previous.number + 1,
      'policy_version' => Preparation::Current::POLICY, 'release_name' => names.release, 'payload_name' => names.payload)
    release.preparation_revisions.create!(attributes)
    payload.update!(locator: names.payload)
    release.reload.update!(preparation_state: 'prepared', proposed_name: names.release)
  end

  def synthetic_cover_evidence(release)
    { 'sha256' => 'c' * 64, 'edition_match' => true, 'quality_reviewed' => true, 'reviewed_facts' => Covers::Policy.facts(release) }
  end

  def synthetic_cover_proof(cover)
    { 'source_sha256' => cover.edition_evidence['sha256'], 'policy' => Covers::Policy::VERSION,
      'edition_fingerprint' => Covers::Policy.fingerprint(cover), 'mean_pixel_difference' => 0.0, 'hosted_sha256' => 'd' * 64 }
  end

  def build_release_graph(include_cover: true)
    release = Release.create!(title: 'Synthetic book', author: 'Test author')
    payload = PayloadRevision.create!(release: release, number: 1, original_filename: 'fixture.epub',
      format: 'epub', size_bytes: 42, sha256: 'a' * 64, locator: 'staging/fixture.epub')
    preparation = PreparationRevision.create!(release: release, payload_revision: payload, number: 1,
      release_name: 'Synthetic book-NOTAG', payload_name: 'Synthetic book-NOTAG.epub',
      torrent_locator: 'torrents/synthetic.torrent', torrent_info_hash: 'b' * 40,
      payload_sha256: payload.sha256, payload_size_bytes: payload.size_bytes,
      policy_version: 'synthetic-v1', prepared_at: Time.current)
    evidence = EvidenceItem.create!(release: release, payload_revision: payload, evidence_key: 'synthetic-title-page',
      kind: 'metadata', source: 'synthetic fixture', captured_at: Time.current, input_revision: 0, data: { title: release.title })
    fact = ReviewedFact.create!(release: release, payload_revision: payload, field: 'title', number: 1,
      value: release.title, actor: 'operator', reviewed_at: Time.current)
    FactEvidenceLink.create!(release: release, reviewed_fact: fact, evidence_item: evidence)
    finding = Finding.create!(release: release, payload_revision: payload, code: 'edition_uncertain', number: 1,
      severity: 'uncertainty', message: 'Synthetic uncertainty', input_revision: 0)
    FindingAcknowledgement.create!(release: release, finding: finding, acknowledged: true, actor: 'operator')
    cover = CoverRevision.create!(release: release, payload_revision: payload, number: 1,
      source_kind: 'embedded', source_locator: 'covers/synthetic.png', width: 600, height: 900, edition_evidence: synthetic_cover_evidence(release)) if include_cover
    connections = { 'publishing' => 'c411', 'torrent_client' => 'deluge', 'ai' => 'openai', 'image_host' => 'postimages' }.to_h do |role, provider|
      connection = ProviderConnection.create!(role: role, provider: provider, identity_key: "synthetic-#{role}", label: "Synthetic #{provider}")
      ProviderAssignment.create!(release: release, role: role, provider_connection: connection, assigned_at: Time.current)
      [ role, connection ]
    end
    CoverHosting.create!(release: release, cover_revision: cover, provider_connection: connections.fetch('image_host'),
      direct_url: 'https://images.invalid/synthetic.png', media_type: 'image/png', width: 600, height: 900, verified_at: Time.current, verification: synthetic_cover_proof(cover)) if cover
    ContentRevision.create!(release: release, payload_revision: payload, preparation_revision: preparation,
      cover_revision_id: cover&.id, kind: 'bbcode', number: 1, body: 'Human text', origin: 'human', input_revision: 0)
    check = DuplicateCheck.create!(release: release, input_revision: 0, searched_at: Time.current)
    DuplicateDecision.create!(release: release, duplicate_check: check, candidate_key: 'synthetic-candidate',
      decision: 'false_positive', reason: 'Different edition', actor: 'operator', reviewed_at: Time.current)
    RemoteSnapshot.create!(release: release, provider_connection: connections.fetch('publishing'), kind: 'draft',
      remote_id: 'synthetic-draft', local_revision: 0, base_content: { body: 'base' }, remote_content: { body: 'remote' }, observed_at: Time.current)
    AiRun.create!(release: release, provider_connection: connections.fetch('ai'), input_revision: 0,
      purpose: 'assessment', prompt_version: 'synthetic-v1', model: 'synthetic', evidence_keys: [ evidence.evidence_key ])
    ReleaseEvent.create!(release: release, sequence: 1, name: 'release.created', actor: 'operator', input_revision: 0, occurred_at: Time.current)
    release
  end
end

RSpec.configure do |config|
  config.include DomainFixtures
end
