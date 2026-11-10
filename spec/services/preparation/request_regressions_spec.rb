require 'rails_helper'

RSpec.describe Preparation::Request do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:paths) { Preparation::Paths.new }

  def start_named(record, name)
    Releases::Save.call(release_id: record.id, expected_revision: record.reload.input_revision, changes: { proposed_name: name })
    Preparation::Request.call(release_id: record.id, expected_revision: record.reload.input_revision)
  end

  it 'preserves an occupied destination and permits explicit preparation under another name' do
    occupied = paths.root.join('Occupied.Author.FRENCH-NOTAG.epub')
    occupied.write('Unrelated bytes')
    first = start_named(release, 'Occupied.Author.FRENCH.[EPUB]-NOTAG')
    Workflows::Execute.call(operation_id: first.id)
    expect(first.reload.result['error_code']).to eq('collision')
    second = start_named(release, 'Free.Author.FRENCH.[EPUB]-NOTAG')
    Workflows::Execute.call(operation_id: second.id)
    expect(release.reload.preparation_state).to eq('prepared')
    expect(occupied.read).to eq('Unrelated bytes')
    expect(paths.root.glob('staging/*.epub')).to be_empty
  end

  it 'releases a journal reservation after a pre-rename collision and changed reviewed name' do
    first = start_named(release, 'Reserved.Author.FRENCH.[EPUB]-NOTAG')
    Workflows::Claim.call(operation_id: first.id)
    payload = release.payload_revisions.sole
    move = Preparation::Reserve.call(operation: first, payload: payload, destination: 'Reserved.Author.FRENCH-NOTAG.epub')
    paths.root.join(move.destination_locator).write('Concurrent bytes')
    Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { proposed_name: 'Free.Author.FRENCH.[EPUB]-NOTAG' })
    Preparation::Reconcile.call(operation: first)
    expect(move.reload.state).to eq('cancelled')
    expect(paths.path(payload.reload.locator)).to be_file
    expect(paths.root.join(move.destination_locator).read).to eq('Concurrent bytes')
  end

  it 'fails closed if the configured payload mount is missing or is a symlink' do
    root = paths.root
    missing = root.join('missing-root')
    storage = Rails.application.config.x.storage
    Rails.application.config.x.storage = storage.merge(payload: missing)
    expect { Preparation::Paths.new.root }.to raise_error(Preparation::Failure)
    expect(missing).not_to exist
    link = root.join('symlink-root')
    link.make_symlink(root)
    Rails.application.config.x.storage = storage.merge(payload: link)
    expect { Preparation::Paths.new.root }.to raise_error(Preparation::Failure, /symbolique/)
  end

  it 'rejects a source with another hard link and a parent swapped for a symlink' do
    source = paths.path(release.payload_revisions.sole.locator)
    File.link(source, paths.root.join('second-link.epub'))
    expect { Preparation::Identity.call(path: source, payload: release.payload_revisions.sole) }.to raise_error(Preparation::Failure)
    paths.root.join('second-link.epub').unlink
    directory = paths.root.join('staging')
    directory.rename(paths.root.join('other'))
    directory.make_symlink(paths.root.join('other'))
    expect { Preparation::Rename.call(source: source, destination: paths.root.join('Book.epub')) }.to raise_error(Preparation::Failure)
    expect(paths.root.join('Book.epub')).not_to exist
  end

  it 'prepares EPUB, PDF and MOBI without converting or duplicating any bytes' do
    %w[epub pdf mobi].each do |format|
      record = staged_preparation_release(format: format)
      operation = start_named(record, "Book.#{format}.FRENCH.[#{format.upcase}]-NOTAG")
      Workflows::Execute.call(operation_id: operation.id)
      payload = record.payload_revisions.sole
      expect(Preparation::Validate.call(release: record.reload).payload_name).to end_with("-NOTAG.#{format}")
      expect(paths.path(payload.locator).binread).to eq("Synthetic preparation bytes\n")
    end
  end

  it 'keeps a changed mapping blocked instead of taking ownership of another root' do
    operation = preparation_operation(release)
    move = Preparation::Reserve.call(operation: operation, payload: release.payload_revisions.sole, destination: 'Book.epub')
    other = paths.root.parent.join('other-mount')
    other.mkpath
    Rails.application.config.x.storage = Rails.application.config.x.storage.merge(payload: other)
    expect { Preparation::Journal.call(move: move) }.to raise_error(Preparation::Failure, /montage/)
    expect(other.children).to be_empty
  end
end
