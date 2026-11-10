require 'rails_helper'

RSpec.describe Drafts::Link do
  let(:shell) { imported_draft }

  def payload_release
    release = Releases::Create.call(title: 'Local upload')
    release.payload_revisions.create!(number: 1, original_filename: 'test.epub', format: 'epub', size_bytes: 42, sha256: 'a' * 64, locator: 'staging/test.epub')
    release
  end

  def link(shell, target, **options)
    described_class.call(release_id: shell.id, payload_release_id: target.id, expected_revision: shell.input_revision,
      payload_revision: target.input_revision, confirmed: true, choice: 'local', **options)
  end

  it 'requires confirmation, preserves both histories and retains local upload content by explicit choice' do
    source = shell
    target = payload_release
    expect { link(source, target, confirmed: false) }.to raise_error(Drafts::Failure)
    link(source, target)
    expect(DraftLink.sole.release_id).to eq(target.id)
    expect(target.reload.title).to eq('Local upload')
    expect(source.reload.content_revisions.last.body).to eq('Description distante conservée.')
    expect([ source, target ]).to all(have_attributes(release_events: include(have_attributes(name: 'draft.linked'))))
  end

  it 'adopts draft text only by explicit choice and leaves the payload identity unchanged' do
    source = shell
    target = payload_release
    identity = target.payload_revisions.sole.attributes
    link(source, target, choice: 'remote')
    expect(Releases::EditorValues.call(release: target.reload)).to include('title' => 'Livre distant', 'bbcode' => 'Description distante conservée.')
    expect(target.payload_revisions.sole.attributes).to eq(identity)
    expect(target.provider_assignments.find_by!(role: 'publishing').provider_connection_id).to eq(DraftLink.sole.provider_connection_id)
  end

  it 'rejects stale targets and another assigned C411 identity' do
    source = shell
    target = payload_release
    expect { link(source, target, payload_revision: -1) }.to raise_error(Releases::RevisionConflict)
    other = create_connection(identity: 'other')
    Settings::AssignConnection.call(release_id: target.id, role: 'publishing', connection_id: other.id, expected_revision: target.input_revision)
    expect { link(source, target.reload) }.to raise_error(Drafts::Failure, /autre identité/)
  end
end
