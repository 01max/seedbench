module RecoveryFixture
  SECRET = 'disposable-synthetic-recovery-value'.freeze
  BYTES = 'Synthetic payload bytes'.freeze

  class << self
    def prepare
      release = Releases::Create.call(title: 'Recovery fixture', author: 'Synthetic author')
      payload.binwrite(BYTES)
      revision = release.payload_revisions.create!(number: 1, locator: payload.basename.to_s, original_filename: 'restore.epub',
        format: 'epub', size_bytes: payload.size, sha256: Digest::SHA256.file(payload).hexdigest)
      release.content_revisions.create!(kind: 'bbcode', number: 1, body: 'Reviewed after upload', origin: 'human', input_revision: 0)
      assign_provider(release)
      queue_inspection(release, revision)
      artifact.dirname.mkpath
      artifact.write('Generated artifact')
      artifact.dirname.dirname.join('operator-sentinel').write('Unrelated file')
    end

    def verify
      release = Release.find_by!(title: 'Recovery fixture')
      abort 'Edited text missing' unless release.content_revisions.sole.body == 'Reviewed after upload'
      connection = release.provider_assignments.find_by!(role: 'publishing').provider_connection
      abort 'Provider identity or key missing' unless connection.credentials.fetch('api_key') == SECRET
      abort 'Release history missing' unless release.release_events.exists?
      abort 'Pending operation missing' unless release.workflow_operations.sole.state == 'pending'
      abort 'Queue job missing' unless SolidQueue::Job.exists?(class_name: 'WorkflowOperationJob')
      abort 'State artifact missing' unless artifact.read == 'Generated artifact'
      abort 'Unrelated file entered the backup' if artifact.dirname.dirname.join('operator-sentinel').exist?

      puts 'Backup retained keys, queue and application records, history, assignments, and artifacts.'
    end

    def mismatch
      payload.binwrite('Mismatched bytes')
    end

    def repair
      payload.binwrite(BYTES)
    end

    private

    def assign_provider(release)
      connection = ProviderConnection.create!(role: 'publishing', provider: 'c411', endpoint: 'https://c411.org', identity_key: 'restore-fixture',
        label: 'Recovery test', credentials: { 'api_key' => SECRET })
      release.provider_assignments.find_by!(role: 'publishing').update!(provider_connection: connection)
    end

    def queue_inspection(release, revision)
      operation = release.workflow_operations.create!(kind: 'inspection', effect: 'local', request_key: 'recovery-queued',
        input_revision: 0, parameters: { 'payload_revision_id' => revision.id })
      operation.create_dispatch_intent!(release: release)
      WorkflowOperationJob.set(wait: 1.hour).perform_later(operation.id)
    end

    def payload
      Preparation::Paths.new.root.join('restore-probe.bin')
    end

    def artifact
      Preparation::Paths.new.root(:state).join('preparation-torrents', 'fixture-artifact')
    end
  end
end

abort 'Use only disposable runtime fixtures' unless ENV['SEEDBENCH_RUNTIME_VERIFICATION'] == '1'
command = ARGV.fetch(0)
abort 'Unknown recovery fixture command' unless %w[prepare verify mismatch repair].include?(command)
RecoveryFixture.public_send(command)
