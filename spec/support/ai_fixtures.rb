module AiFixtures
  def configure_ai(release)
    connection = release.provider_assignments.find_by!(role: 'ai').provider_connection
    connection.update!(endpoint: 'https://api.openai.com', credentials: { 'api_key' => 'synthetic-openai-key' }, options: { model: 'gpt-4.1-mini-2025-04-14' })
    connection
  end

  def ai_output(pack, purpose: 'assessment')
    id = pack.fetch('items').find { |item| item['kind'] == 'reviewed' }.fetch('id')
    return { 'presentation' => 'Une lecture à découvrir au fil des extraits présentés.', 'notes' => nil,
      'evidence_ids' => [ id ], 'limitations' => 'Analyse limitée aux extraits fournis.' } if purpose == 'prose'

    { 'candidates' => [ { 'field' => 'title', 'value' => 'Synthetic book', 'evidence_ids' => [ id ] } ],
      'findings' => [ { 'summary' => 'L’édition reste à comparer manuellement.', 'evidence_ids' => [ id ] } ], 'limitations' => 'Extraits uniquement.' }
  end

  def ai_response(output, status: 'completed')
    { id: 'resp_synthetic', status: status, model: 'gpt-4.1-mini-2025-04-14',
      output: [ { type: 'message', role: 'assistant', content: [ { type: 'output_text', text: JSON.generate(output) } ] } ],
      usage: { input_tokens: 120, output_tokens: 60, total_tokens: 180 } }.to_json
  end

  def build_ai_run(release, purpose: 'assessment')
    connection = release.provider_assignments.find_by!(role: 'ai').provider_connection
    pack = Ai::EvidencePack.call(release: release)
    operation = Workflows::Start.call(release_id: release.id, kind: "ai_#{purpose}", request_key: SecureRandom.uuid,
      expected_revision: release.input_revision, parameters: { purpose: purpose })
    release.ai_runs.create!(workflow_operation_id: operation.id, provider_connection: connection, purpose: purpose,
      input_revision: release.input_revision, prompt_version: Ai::Prompts.call(purpose: purpose).fetch('version'), model: connection.options.fetch('model'),
      evidence_keys: pack.fetch('items').pluck('id'), request: { pack: pack, connection_version: connection.credentials_version })
  end
end

RSpec.configure { |config| config.include AiFixtures }
