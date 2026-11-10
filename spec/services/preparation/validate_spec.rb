require 'rails_helper'

RSpec.describe Preparation::Validate do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:paths) { Preparation::Paths.new }

  def prepare(name = 'Synthetic.Book.Test.Author.FRENCH.[EPUB]-NOTAG')
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { proposed_name: name })
    operation = Preparation::Request.call(release_id: release.id, expected_revision: release.reload.input_revision)
    Workflows::Execute.call(operation_id: operation.id)
    release.reload.preparation_revisions.order(number: :desc).first!
  end

  it 'keeps an accepted preparation current under its recorded root' do
    preparation = prepare
    expect(described_class.call(release: release.reload)).to eq(preparation)
    Preparation::Observe.call(release: release)
    expect(release.reload.preparation_state).to eq('prepared')
  end

  it 'invalidates a changed root even when the copied canonical bytes and torrent match' do
    preparation = prepare
    original = paths.path(preparation.payload_name)
    replacement = paths.root.parent.join('replacement-root')
    replacement.mkpath
    FileUtils.cp(original, replacement.join(preparation.payload_name))
    Rails.application.config.x.storage = Rails.application.config.x.storage.merge(payload: replacement)
    expect { described_class.call(release: release.reload) }.to raise_error(Preparation::Failure, /montage/)
    Preparation::Observe.call(release: release)
    expect(release.reload.preparation_state).to eq('stale')
    expect(original).to be_file
    expect(replacement.join(preparation.payload_name).binread).to eq(original.binread)
  end

  it 'validates the accepted preparation after explicitly preparing a new name' do
    prepare
    preparation = prepare('Corrected.Book.Test.Author.FRENCH.[EPUB]-NOTAG')
    expect(release.payload_revisions.sole.payload_moves.where(state: 'completed').count).to eq(2)
    expect(described_class.call(release: release.reload)).to eq(preparation)
  end
end
