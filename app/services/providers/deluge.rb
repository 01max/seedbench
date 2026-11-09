module Providers
  class Deluge
    def self.check(connection:)
      client = new(connection)
      client.authenticate!(connection.credentials.fetch('password'))
      client.connect!(connection.identity_key)

      CheckResult.new(status: 'passed', code: 'daemon_connected', message: I18n.t('messages.providers.deluge.authentification_et_connexion_au_demon_verifiees'))
    end

    def authenticate!(password)
      raise Failure.new('authentication_failed', I18n.t('messages.providers.deluge.mot_de_passe_deluge_refuse')) unless rpc('auth.login', [ password ]) == true
    end

    def connect!(identity)
      hosts = rpc('web.get_hosts')
      raise Failure.new('daemon_missing', I18n.t('messages.providers.deluge.le_demon_deluge_enregistre_est_absent')) unless hosts.is_a?(Array) && hosts.any? { |host| host.is_a?(Array) && host.first == identity }

      rpc('web.connect', [ identity ])
      raise Failure.new('daemon_disconnected', I18n.t('messages.providers.deluge.le_demon_deluge_nest_pas_connecte')) unless rpc('web.connected') == true
    end

    def initialize(connection)
      @endpoint = connection.endpoint
      @cookies = ''
      @sequence = 0
    end

    def rpc(method, parameters = [])
      @sequence += 1
      response = Http.call(endpoint: @endpoint, path: '/json', headers: { 'Content-Type' => 'application/json', 'Cookie' => @cookies },
        body: { method: method, params: parameters, id: @sequence })
      @cookies = response.cookies unless response.cookies.empty?
      data = Http.json(response)
      raise Failure.new('rpc_failed', I18n.t('messages.providers.deluge.deluge_a_refuse_la_requete_verifiez')) unless data.is_a?(Hash) && data['id'] == @sequence && data['error'].nil? && data.key?('result')

      data['result']
    end
  end
end
