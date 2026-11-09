module Providers
  class Postimages
    def self.check(**)
      response = Http.call(endpoint: 'https://postimages.org', path: '/')
      raise Failure.new('invalid_response', I18n.t('messages.providers.postimages.la_page_postimages_na_pas_pu')) unless response.body.include?('postimages') || response.body.include?('Postimages')

      CheckResult.new(status: 'limited', code: 'reachability_only', message: I18n.t('messages.providers.postimages.site_accessible_cle_et_envoi_non'))
    end
  end
end
