module Providers
  # Checks that the configured model can generate a response to a synthetic prompt.
  class Openai
    def self.check(connection:)
      body = { model: connection.options.fetch('model'), input: I18n.t('messages.providers.openai.test_prompt'), store: false, max_output_tokens: 512 }
      response = Http.call(endpoint: connection.endpoint, path: '/v1/responses', body: body, total_timeout: 25, read_timeout: 20,
        headers: { 'Authorization' => "Bearer #{connection.credentials.fetch('api_key')}", 'Content-Type' => 'application/json' })
      raise Ai::Failure.new(:invalid_output) if Response.text(data: Http.json(response)).blank?

      CheckResult.new(status: 'passed', code: 'response_received', message: I18n.t('messages.providers.openai.test_response_received'))
    rescue Ai::Failure
      raise Failure.new('invalid_response', I18n.t('messages.providers.openai.test_response_invalid')), cause: nil
    end
  end
end
