module Providers
  # Authenticates a Deluge Web connection and forwards RPC calls to its selected daemon.
  class Deluge
    def self.check(connection:)
      client = new(endpoint: connection.endpoint)
      client.authenticate!(connection.credentials.fetch('password'))
      client.connect!(connection.identity_key)

      CheckResult.new(status: 'passed', code: 'daemon_connected', message: I18n.t('messages.providers.deluge.authentification_et_connexion_au_demon_verifiees'))
    end

    def self.discover(endpoint:, password:)
      client = new(endpoint: endpoint)
      client.authenticate!(password)
      client.daemons
    end

    def daemons
      hosts.filter_map { |host| daemon(host) }
    end

    def authenticate!(password)
      raise Failure.new('authentication_failed', I18n.t('messages.providers.deluge.mot_de_passe_deluge_refuse')) unless rpc('auth.login', [ password ]) == true
    end

    def connect!(identity)
      raise Failure.new('daemon_missing', I18n.t('messages.providers.deluge.le_demon_deluge_enregistre_est_absent')) unless hosts.any? { |host| host.is_a?(Array) && host.first == identity }

      rpc('web.connect', [ identity ])
      raise Failure.new('daemon_disconnected', I18n.t('messages.providers.deluge.le_demon_deluge_nest_pas_connecte')) unless rpc('web.connected') == true
    end

    def initialize(endpoint:)
      @endpoint = endpoint
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

    private

    def hosts
      result = rpc('web.get_hosts')
      raise Failure.new('invalid_daemon_list', I18n.t('messages.providers.deluge.invalid_daemon_list')) unless result.is_a?(Array)

      result
    end

    def daemon(host)
      return unless host in [ String => id, String => address, Integer => port, * ]
      return unless id.match?(/\A[a-zA-Z0-9_.:-]{1,120}\z/) && address.present? && (1..65_535).cover?(port)

      username = host[3]
      { id: id, address: address, port: port, username: (username if username.is_a?(String)) }
    end
  end
end
