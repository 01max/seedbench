require 'tmpdir'
require 'timeout'

module RuntimePreparation
  def self.checkpoint
    Rails.application.config.x.storage.fetch(:scratch).join('runtime-preparation.json')
  end

  def self.saved
    JSON.parse(checkpoint.read)
  end

  def self.start
    release = synthetic_release
    inspection = release.workflow_operations.where(kind: 'inspection').sole
    Workflows::Execute.call(operation_id: inspection.id)
    release.reload
    abort 'Synthetic preparation requires successful inspection' unless release.inspection_state == 'succeeded'
    Releases::Save.call(release_id: release.id, expected_revision: release.input_revision,
      changes: { proposed_name: 'Runtime.Prepared.Book.FRENCH.[EPUB]-NOTAG', language: 'fr' })
    release.reload
    operation = Workflows::Start.call(release_id: release.id, kind: 'preparation', request_key: 'interrupted-preparation',
      expected_revision: release.input_revision, parameters: { payload_revision_id: release.payload_revisions.sole.id,
        release_name: release.proposed_name, pause_after_rename: true })
    release.update!(preparation_state: 'running')
    payload = release.payload_revisions.sole
    path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)
    checkpoint.write(JSON.generate(operation_id: operation.id, release_id: release.id, original_locator: payload.locator,
      device: path.stat.dev, inode: path.stat.ino, sha256: payload.sha256, size: payload.size_bytes))
  end

  def self.synthetic_release
    scratch = Rails.application.config.x.storage.fetch(:scratch)
    Dir.mktmpdir('runtime-preparation-', scratch) do |directory|
      code = "import sys,pathlib;sys.path.insert(0,'script/ebooks');import fixtures;fixtures.epub(pathlib.Path(sys.argv[1]))"
      system('python3', '-c', code, directory, exception: true)
      File.open(File.join(directory, 'book.epub'), 'rb') do |file|
        upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: 'runtime-preparation.epub', type: 'application/epub+zip')
        Releases::Intake.call(uploads: [ upload ]).releases.sole
      end
    end
  end

  def self.await_rename
    data = saved
    operation = WorkflowOperation.find(data.fetch('operation_id'))
    marker = Rails.application.config.x.storage.fetch(:scratch).join("preparation-renamed-#{operation.id}")
    Timeout.timeout(15) { sleep 0.05 until marker.exist? }
    move = PayloadMove.find_by!(workflow_operation_id: operation.id)
    abort 'Move outcome was already committed before interruption' unless move.state == 'reserved' && operation.release.payload_revisions.sole.locator == move.source_locator
    destination = Rails.application.config.x.storage.fetch(:payload).join(move.destination_locator)
    abort 'Rename lost the original file inode' unless destination.stat.ino == data.fetch('inode')
    abort 'Rename retained staging data' if Rails.application.config.x.storage.fetch(:payload).join(move.source_locator).exist?
    puts 'Real worker reached the post-rename/pre-commit interruption point with one unchanged inode.'
  end

  def self.recover
    data = saved
    operation = WorkflowOperation.find(data.fetch('operation_id'))
    abort 'Killed preparation did not retain its running operation' unless operation.state == 'running'
    operation.update!(lease_expires_at: 1.second.ago)
    Rails.application.config.x.storage.fetch(:scratch).join("preparation-continue-#{operation.id}").write('continue')
  end

  def self.verify
    data = saved
    release = Release.find(data.fetch('release_id'))
    operation = WorkflowOperation.find(data.fetch('operation_id'))
    payload = release.payload_revisions.sole
    path = Rails.application.config.x.storage.fetch(:payload).join(payload.locator)
    abort 'Preparation was not recovered exactly once' unless operation.state == 'succeeded' && operation.attempts == 2 && release.preparation_revisions.count == 1
    abort 'Preparation changed payload identity across recreation' unless [ path.stat.dev, path.stat.ino, path.size, Digest::SHA256.file(path).hexdigest ] == data.values_at('device', 'inode', 'size', 'sha256')
    abort 'Original staging copy remains' if Rails.application.config.x.storage.fetch(:payload).join(data.fetch('original_locator')).exist?
    abort 'Preparation lost its current private torrent' unless Preparation::Validate.call(release: release).torrent_info_hash.match?(/\A[0-9a-f]{40}\z/)
    abort 'Preparation created remote state' if release.remote_snapshots.exists?
    puts 'Killed preparation recovered one canonical inode, unchanged bytes and verified private torrent across container recreation.'
  end
end
