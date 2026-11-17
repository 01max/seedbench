module ProviderHelpers
  def connection_attributes(role = 'publishing', identity: 'synthetic-account')
    definition = Providers::Catalog.fetch(role)
    { role: role, label: "Synthetic #{definition.name}", identity_key: identity,
      endpoint: definition.endpoint || 'http://deluge.test:8112',
      credentials: { definition.secret => role == 'image_host' ? 'a' * 32 : 'synthetic-private-credential' },
      options: role == 'ai' ? { 'model' => 'synthetic-model' } : {} }
  end

  def create_connection(role = 'publishing', identity: 'synthetic-account')
    if role == 'publishing'
      stub_request(:get, 'https://c411.org/api/user/drafts').to_return(body: { success: true, data: [], count: 0, maxAllowed: 15 }.to_json)
    end
    Settings::CreateConnection.call(**connection_attributes(role, identity: identity))
  end

  def stub_openai_connection_check(model: 'synthetic-model', api_key: 'synthetic-private-credential')
    stub_request(:post, 'https://api.openai.com/v1/responses')
      .with(headers: { 'Authorization' => "Bearer #{api_key}" }, body: hash_including(model: model, store: false, max_output_tokens: 512))
      .to_return(body: { id: 'resp_synthetic_check', model: model, status: 'completed',
                         output: [ { type: 'message', role: 'assistant', content: [ { type: 'output_text', text: 'OK' } ] } ] }.to_json)
  end

  def stub_deluge(results)
    %w[auth.login web.get_hosts web.connect web.connected].zip(results).each_with_index do |(method, result), index|
      stub_request(:post, 'http://deluge.test:8112/json').with { |request| JSON.parse(request.body)['method'] == method }
        .to_return(body: { id: index + 1, result: result, error: nil }.to_json, headers: { 'Set-Cookie' => '_session_id=synthetic; HttpOnly' })
    end
  end
end

RSpec.configure { |config| config.include ProviderHelpers }
