abort 'Use only the disposable runtime stack' unless ENV['SEEDBENCH_RUNTIME_VERIFICATION'] == '1'

module RuntimeAi
  class << self
    def prepare
      release = release_fixture
      run = nil
      release.with_lock do
        run = Ai::Request.call(release_id: release.id, expected_revision: release.input_revision, purpose: 'prose')
        token = Workflows::Claim.call(operation_id: run.workflow_operation_id)
        result = { 'status' => 'succeeded', 'output' => { 'presentation' => 'Une proposition synthétique à relire.', 'notes' => nil,
          'evidence_ids' => run.evidence_keys.first(1), 'limitations' => 'Extrait synthétique uniquement.' }, 'response_model' => run.model }
        Workflows::Complete.call(operation_id: run.workflow_operation_id, attempt_token: token, result: result, apply: Ai::Record)
      end
      Rails.application.config.x.storage.fetch(:scratch).join('runtime-ai.json').write(JSON.generate(run_id: run.id,
        request_sha256: Digest::SHA256.hexdigest(JSON.generate(run.request))))
    end

    def verify
      saved = JSON.parse(Rails.application.config.x.storage.fetch(:scratch).join('runtime-ai.json').read)
      run = AiRun.find(saved.fetch('run_id'))
      abort 'AI request provenance changed across recreation' unless Digest::SHA256.hexdigest(JSON.generate(run.request)) == saved.fetch('request_sha256')
      abort 'AI result or workflow disappeared' unless run.status == 'succeeded' && run.workflow_operation.state == 'succeeded'
      abort 'AI silently replaced human prose' unless run.release.content_revisions.where(kind: 'presentation').sole.body == 'Texte humain à conserver.'
      abort 'AI silently reviewed facts' if run.release.reviewed_facts.exists?
      abort 'AI lost its cited evidence' unless run.evidence_keys.include?(run.result.fetch('output').fetch('evidence_ids').sole)
      puts 'Focused AI request, citations, unaccepted suggestion and human text survived recreation without provider calls.'
    end

    private

    def release_fixture
      connection = Settings::CreateConnection.call(role: 'ai', label: 'Synthetic runtime AI', identity_key: 'runtime-ai',
        credentials: { api_key: 'synthetic-runtime-ai-key' }, options: { model: 'synthetic-model' })
      release = Releases::Create.call(title: 'Synthetic assistance fixture')
      release.payload_revisions.create!(number: 1, original_filename: 'ai.epub', format: 'epub', size_bytes: 42, sha256: 'b' * 64, locator: 'synthetic-ai.epub')
      release.evidence_items.create!(payload_revision: release.payload_revisions.sole, evidence_key: 'runtime-ai-excerpt', kind: 'inspection', source: 'Synthetic excerpt',
        captured_at: Time.current, input_revision: release.input_revision, data: { samples: [ { source: 'opening', text: 'Un récit fictif sur un jardin.' } ] })
      release.update!(inspection_state: 'succeeded')
      Settings::AssignConnection.call(release_id: release.id, role: 'ai', connection_id: connection.id, expected_revision: release.input_revision)
      Releases::Save.call(release_id: release.id, expected_revision: release.reload.input_revision, changes: { presentation: 'Texte humain à conserver.' })
    end
  end
end
