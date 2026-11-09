require 'rails_helper'

RSpec.describe Content::Generate do
  let(:release) { reviewed_content_release }

  it 'generates the exact template and NFO using reviewed facts and measured file identity' do
    result = described_class.call(release: release)
    expect(result.issues).to be_empty
    expect(result.bodies['bbcode']).to include('[b]Éditeur :[/b] Synthetic publisher', '[b]ISBN numérique :[/b] 9780306406157', '42 octets (0,00 Mo)')
    expect(result.bodies['nfo']).to include('Format : EPUB', 'Fichier(s) : 1 EPUB', 'Documents EPUB : 5')
    expect(result.dependencies['bbcode']).to include('payload_revision_id' => release.payload_revisions.sole.id)
    expect(release.content_revisions.where(kind: 'bbcode').sole.body).to eq('Human text')
  end

  it 'leaves the cover visibly incomplete instead of inventing or hosting a URL' do
    release.provider_assignments.find_by!(role: 'image_host').update!(provider_connection_id: nil)
    result = described_class.call(release: release)
    expect(result.bodies['bbcode']).to start_with('[center][img][/img][/center]')
    expect(result.issues.pluck(:code)).to include('cover')
    expect(release.cover_hostings.count).to eq(1)
  end

  it 'generates and accepts NFO for reviewed facts with surrounding whitespace' do
    author = "  Test author \t "
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { author: author, publisher: ' Synthetic publisher ' })
    expect(described_class.call(release: release.reload).issues).to be_empty

    proposal = Content::Propose.call(release_id: release.id, expected_revision: release.input_revision, kind: 'nfo')
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)

    expect(Content::Status.call(release: release.reload).kinds['nfo'][:state]).to eq('ready')
    expect(release.reviewed_facts.where(field: 'author').order(:number).last.value).to eq(author)
  end

  it 'does not turn a print ISBN into a digital ISBN' do
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { isbn_kind: 'print' })
    result = described_class.call(release: release.reload)
    expect(result.bodies['bbcode']).to include('[b]ISBN numérique :[/b] Non applicable')
    expect(result.bodies['nfo']).to include('ISBN de l’édition imprimée : 9780306406157')
  end

  it 'does not elevate embedded or filename-derived facts without review' do
    record = Releases::Create.call(title: 'Filename guess')
    result = described_class.call(release: record)
    expect(result.bodies['bbcode']).not_to include('Filename guess')
    expect(result.issues.pluck(:code)).to include('inspection_required', 'missing_value')
  end

  it 'changes only the NFO dependency when measured document counts change' do
    before = described_class.call(release: release)
    release.evidence_items.create!(payload_revision: release.payload_revisions.sole, evidence_key: 'new-counts', kind: 'inspection', source: 'Synthetic parser',
      captured_at: Time.current, input_revision: release.input_revision, data: { error: nil, structure: { spine_documents: 6, page_count: nil } })
    after = described_class.call(release: release)
    expect(after.dependencies.dig('bbcode', 'fingerprint')).to eq(before.dependencies.dig('bbcode', 'fingerprint'))
    expect(after.dependencies.dig('nfo', 'fingerprint')).not_to eq(before.dependencies.dig('nfo', 'fingerprint'))
  end
end
