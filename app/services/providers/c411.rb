module Providers
  class C411
    def self.check(connection:)
      response = Http.call(endpoint: connection.endpoint, path: '/api/user/drafts',
        headers: { 'Authorization' => "Bearer #{connection.credentials.fetch('api_key')}" })
      data = Http.json(response)
      raise Failure.new('invalid_response', I18n.t('messages.providers.c411.la_liste_de_brouillons_na_pas')) unless data.is_a?(Hash) && data['success'] == true && data['data'].is_a?(Array)

      CheckResult.new(status: 'passed', code: 'draft_list', message: I18n.t('messages.providers.c411.lecture_des_brouillons_autorisee_publication_et'))
    end
  end
end
