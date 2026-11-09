require 'rails_helper'

RSpec.describe Content::CoverPatch do
  let(:release) { reviewed_content_release }

  it 'changes only the cover URL after explicit acceptance of the patch' do
    draft = Content::Generate.call(release: release)
    body = draft.bodies['bbcode'].sub('https://images.invalid/synthetic.png', 'https://old.invalid/cover.png').sub('Présentation originale de test.', 'Prose humaine à conserver.\n[quote]Texte relu[/quote]')
    body = body.sub('Aucune.', 'Conserver https://old.invalid/cover.png dans ces notes.')
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { bbcode: body })
    proposal = described_class.call(release_id: release.id, expected_revision: release.reload.input_revision)
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq(body)
    Content::Accept.call(release_id: release.id, proposal_id: proposal.id, expected_revision: release.input_revision)
    expect(release.content_revisions.where(kind: 'bbcode').last.body).to eq(body.sub('https://old.invalid/cover.png', 'https://images.invalid/synthetic.png'))
  end

  it 'does not guess where a cover belongs in malformed manual text' do
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision) }.to raise_error(described_class::Unavailable)
    expect(release.content_proposals).to be_empty
  end
end
