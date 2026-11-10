module Providers
  class Openai
    class Generate
      def self.call(connection:, model:, purpose:, pack:, max_output_tokens: 2500)
        prompt = Ai::Prompts.call(purpose: purpose)
        body = { model: model, store: false, max_output_tokens: max_output_tokens,
          input: [ { role: 'developer', content: prompt.fetch('instructions') }, { role: 'user', content: JSON.generate(pack) } ],
          text: { format: { type: 'json_schema', name: "ebook_#{purpose}", strict: true,
            schema: Ai::Schemas.call(purpose: purpose, evidence_ids: pack.fetch('items').pluck('id')) } } }
        response = Http.call(endpoint: connection.endpoint, path: '/v1/responses', body: body, total_timeout: 90, read_timeout: 60,
          headers: { 'Authorization' => "Bearer #{connection.credentials.fetch('api_key')}", 'Content-Type' => 'application/json' })
        Response.call(data: Http.json(response), purpose: purpose, pack: pack)
      end
    end
  end
end
