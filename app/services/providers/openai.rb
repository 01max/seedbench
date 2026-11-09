module Providers
  class Openai
    def self.check(connection:)
      model = connection.options.fetch('model')
      response = Http.call(endpoint: connection.endpoint, path: "/v1/models/#{model}",
        headers: { 'Authorization' => "Bearer #{connection.credentials.fetch('api_key')}" })
      data = Http.json(response)
      raise Failure.new('invalid_response', I18n.t('messages.providers.openai.le_modele_demande_na_pas_pu')) unless data.is_a?(Hash) && data['id'] == model && data['object'] == 'model'

      CheckResult.new(status: 'passed', code: 'model_read', message: I18n.t('messages.providers.openai.acces_au_modele_verifie_generation_et'))
    end
  end
end
