require 'rails_helper'

RSpec.describe Preparation::Request do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:paths) { Preparation::Paths.new }

  def request_preparation
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision,
      changes: { proposed_name: 'Synthetic.Book.Test.Author.FRENCH.[EPUB]-NOTAG' }) if release.proposed_name.blank?
    described_class.call(release_id: release.id, expected_revision: release.reload.input_revision)
  end

  def execute_preparation
    operation = request_preparation
    Workflows::Execute.call(operation_id: operation.id)
    operation.reload
  end

  it 'verifies preparation once and leaves the canonical payload in place on repeated delivery' do
    operation = execute_preparation
    Workflows::Execute.call(operation_id: operation.id)
    expect(release.preparation_revisions.count).to eq(1)
    expect(Preparation::Validate.call(release: release.reload)).to eq(release.preparation_revisions.sole)
    expect(paths.root.glob('staging/*.epub')).to be_empty
    expect(paths.root.glob('*.epub').size).to eq(1)
    expect(release.workflow_operations.count).to eq(1)
  end

  it 'marks a changed name stale and explicitly re-prepares the same inode' do
    execute_preparation
    original = paths.path(release.payload_revisions.sole.locator)
    inode = original.stat.ino
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision,
      changes: { proposed_name: 'Corrected.Book.Test.Author.FRENCH.[EPUB]-NOTAG' })
    expect(release.reload.preparation_state).to eq('stale')
    execute_preparation
    expect(original).not_to exist
    expect(paths.path(release.payload_revisions.sole.locator).stat.ino).to eq(inode)
    expect(release.preparation_revisions.count).to eq(2)
  end

  it 'detects same-size byte changes and blocks current-preparation gates' do
    execute_preparation
    payload = release.payload_revisions.sole
    paths.path(payload.locator).binwrite('X' * payload.size_bytes)
    Preparation::Observe.call(release: release.reload)
    expect(release.reload.preparation_state).to eq('stale')
    expect { Preparation::Validate.call(release: release) }.to raise_error(Preparation::Failure)
    expect(paths.path(payload.locator)).to be_file
  end

  it 'replays a journal safely after an expired worker lease and fences the old attempt' do
    operation = request_preparation
    first = Workflows::Claim.call(operation_id: operation.id)
    payload = release.payload_revisions.sole
    name = Providers::C411::EbookNaming.from_release(name: release.reload.proposed_name, format: 'epub').payload
    Preparation::Reserve.call(operation: operation, payload: payload, destination: name)
    Preparation::Rename.call(source: paths.path(payload.locator), destination: paths.path(name, missing: true))
    operation.reload.update!(lease_expires_at: 1.second.ago)
    Workflows::Lease.recover(limit: 100)
    Workflows::Execute.call(operation_id: operation.id)
    Workflows::Complete.call(operation_id: operation.id, attempt_token: first, result: {}, apply: Preparation::Record)
    expect(release.reload.preparation_state).to eq('prepared')
    expect(release.preparation_revisions.count).to eq(1)
  end

  it 'reconciles location without accepting obsolete preparation after an edit during interruption' do
    operation = request_preparation
    Workflows::Claim.call(operation_id: operation.id)
    names = Providers::C411::EbookNaming.from_release(name: release.reload.proposed_name, format: 'epub')
    Preparation::Move.call(operation: operation.reload, names: names)
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { bbcode: 'Newer human text' })
    operation.reload.update!(lease_expires_at: 1.second.ago)
    Workflows::Lease.recover(limit: 100)
    Workflows::Execute.call(operation_id: operation.id)
    expect(operation.reload.state).to eq('stale')
    expect(paths.path(release.payload_revisions.sole.locator)).to be_file
    expect(release.preparation_revisions).to be_empty
    expect(Releases::EditorValues.call(release: release.reload).fetch('bbcode')).to eq('Newer human text')
  end

  it 'requires a reviewed name, current revision and successful inspection' do
    expect { described_class.call(release_id: release.id, expected_revision: 0) }.to raise_error(Providers::C411::EbookNaming::InvalidName)
    expect { described_class.call(release_id: release.id, expected_revision: 9) }.to raise_error(Releases::RevisionConflict)
    release.update!(inspection_state: 'failed')
    expect { described_class.call(release_id: release.id, expected_revision: 0) }.to raise_error(Preparation::Failure, /inspection/)
    expect(release.workflow_operations).to be_empty
  end

  it 'rejects published name changes and preparation without moving seeded data' do
    execute_preparation
    release.reload.update!(publication_state: 'published')
    expect { Releases::Save.call(release_id: release.id, expected_revision: release.input_revision, changes: { proposed_name: 'Other' }) }.to raise_error(Preparation::Failure, /publié/)
    expect { described_class.call(release_id: release.id, expected_revision: release.input_revision) }.to raise_error(Preparation::Failure, /publié/)
    expect(paths.path(release.payload_revisions.sole.locator)).to be_file
  end
end
