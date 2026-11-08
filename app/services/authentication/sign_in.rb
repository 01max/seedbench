require "digest"

module Authentication
  class SignIn
    class InvalidCredentials < StandardError; end
    Result = Data.define(:token, :expires_at)

    def self.call(password:, ip:)
      Throttle.check!(ip: ip)
      operator = Operator.find_by(id: 1)
      raise InvalidCredentials unless operator&.authenticate(password.to_s)

      digest = operator.password_digest
      operator.with_lock do
        raise InvalidCredentials unless operator.password_digest == digest

        token = SecureRandom.urlsafe_base64(32)
        record = operator.login_sessions.create!(token_digest: Digest::SHA256.hexdigest(token), expires_at: 12.hours.from_now)
        Result.new(token: token, expires_at: record.expires_at)
      end
    end
  end
end
