require "net/http"
require "nokogiri"
require "json"
require "digest"

abort "Use only the disposable runtime stack" unless ENV["SEEDBENCH_RUNTIME_VERIFICATION"] == "1"

module RuntimeAccess
  PASSWORD = "Synthetic runtime operator password"
  SECRET = "synthetic-runtime-provider-secret"

  def self.request(method, path, cookies, fields = {})
    uri = URI("http://127.0.0.1:3000#{path}")
    request = method.new(uri)
    request["Cookie"] = cookies.map { |key, value| "#{key}=#{value}" }.join("; ")
    request.set_form_data(fields) unless fields.empty?
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 10) { |http| http.request(request) }
    response.get_fields("set-cookie").to_a.each do |cookie|
      key, value = cookie.split(";", 2).first.split("=", 2)
      cookies[key] = value
    end
    response
  end

  def self.prepare
    Authentication::ResetPassword.call(password: PASSWORD, password_confirmation: PASSWORD)
    cookies = {}
    login = request(Net::HTTP::Get, "/session/new", cookies)
    token = Nokogiri::HTML(login.body).at_css('meta[name="csrf-token"]')["content"]
    accepted = request(Net::HTTP::Post, "/session", cookies, { "operator[password]" => PASSWORD, authenticity_token: token })
    abort "Production login failed" unless accepted.code == "303"
    abort "Authenticated Settings failed" unless request(Net::HTTP::Get, "/settings", cookies).code == "200"
    prepare_defaults
    scratch = Rails.application.config.x.storage.fetch(:scratch)
    scratch.join("runtime-browser-cookies.json").write(JSON.generate(cookies))
    scratch.join("runtime-encryption-hash").write(Digest::SHA256.file(key_path).hexdigest)
  end

  def self.prepare_defaults
    connection = Settings::CreateConnection.call(role: "publishing", label: "Runtime provider", identity_key: "runtime-account", credentials: { api_key: SECRET })
    ids = Providers::Catalog::ROLES.keys.index_with { |role| role == "publishing" ? connection.id : nil }
    Settings::SetDefaults.call(automatic_ai: false, connection_ids: ids, expected_revision: 0)
    Releases::Create.call(title: "Synthetic future release")
  end

  def self.key_path
    Rails.application.config.x.storage.fetch(:state).join("provider_encryption_key")
  end

  def self.verify
    scratch = Rails.application.config.x.storage.fetch(:scratch)
    cookies = JSON.parse(scratch.join("runtime-browser-cookies.json").read)
    abort "Session lost across recreation" unless request(Net::HTTP::Get, "/settings", cookies).code == "200"
    forged = request(Net::HTTP::Patch, "/settings", cookies, { authenticity_token: "forged", "defaults[automatic_ai]" => "1" })
    abort "Production CSRF protection missing" unless forged.code == "422" && OperatorPreference.sole.automatic_ai == false
    verify_defaults
    abort "Encryption key changed" unless Digest::SHA256.file(key_path).hexdigest == scratch.join("runtime-encryption-hash").read
    abort "Encryption key permissions too broad" unless (key_path.stat.mode & 0o077).zero?
    Authentication::ResetPassword.call(password: "Replacement synthetic runtime password", password_confirmation: "Replacement synthetic runtime password")
    abort "Reset did not revoke browser session" unless request(Net::HTTP::Get, "/", cookies).code == "302"
    abort "Old password remained usable" if Operator.sole.valid_password?(PASSWORD)
    puts "Login, CSRF, encrypted credentials, key/session persistence, future defaults and password-reset revocation verified."
  end

  def self.verify_defaults
    connection = ProviderConnection.find_by!(identity_key: "runtime-account")
    abort "Credentials failed to decrypt" unless connection.credentials == { "api_key" => SECRET }
    stored = ApplicationRecord.connection.select_value("SELECT credentials FROM provider_connections WHERE id = #{connection.id}")
    abort "Credentials stored in plaintext" if stored.include?(SECRET)
    future = Release.find_by!(title: "Synthetic future release")
    abort "Future release choices changed" unless future.automatic_ai == false && future.provider_assignments.find_by!(role: "publishing").provider_connection_id == connection.id
    abort "Existing release AI choice changed" unless RuntimeWorkflows.release.automatic_ai
  end
end
