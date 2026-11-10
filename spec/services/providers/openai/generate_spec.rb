require 'rails_helper'

RSpec.describe Providers::Openai::Generate do
  let(:release) { reviewed_content_release }
  let(:connection) { configure_ai(release) }
  let(:pack) { Ai::EvidencePack.call(release: release) }

  def generate
    described_class.call(connection: connection, model: connection.options.fetch('model'), purpose: 'assessment', pack: pack)
  end

  it 'sends bounded lower-trust evidence with strict schema, the exact model, no tools and no response storage' do
    stub_request(:post, 'https://api.openai.com/v1/responses').with do |sent|
      body = JSON.parse(sent.body)
      expect(body).to include('store' => false, 'model' => connection.options['model'])
      expect(body.keys).not_to include('tools', 'previous_response_id', 'conversation')
      expect(body.dig('text', 'format')).to include('strict' => true, 'type' => 'json_schema')
      expect(body['input'].pluck('role')).to eq(%w[developer user])
      true
    end.to_return(body: ai_response(ai_output(pack)))
    expect(generate).to include('response_model' => connection.options['model'], 'output' => ai_output(pack))
  end

  it 'rejects refused, incomplete, malformed and action-tool outputs without retaining raw content' do
    responses = [ ai_response({}, status: 'incomplete'), '<html>synthetic-openai-key</html>',
      { id: 'resp_synthetic', model: 'test', status: 'completed', output: [ { type: 'function_call' } ] }.to_json ]
    responses.each do |body|
      stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: body)
      expect { generate }.to raise_error(body.start_with?('<') ? Providers::Failure : Ai::Failure)
    end
  end

  it 'keeps a refusal unusable without retaining the refusal text' do
    data = JSON.parse(ai_response({}))
    data['output'].first['content'] = [ { 'type' => 'refusal', 'refusal' => 'Synthetic refusal body' } ]
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: JSON.generate(data))
    expect { generate }.to raise_error(Ai::Failure) { |error| expect(error.code).to eq('refused') }
  end

  it 'sanitizes transport failures without automatically retrying the paid request' do
    request = stub_request(:post, 'https://api.openai.com/v1/responses').to_timeout
    expect { generate }.to raise_error(Providers::Failure) { |error| expect(error.message).not_to include('synthetic-openai-key') }
    expect(request).to have_been_requested.once
  end
end
