require "digest"

module Authentication
  class Resume
    def self.call(token:)
      return if token.blank?

      LoginSession.includes(:operator).find_by(token_digest: Digest::SHA256.hexdigest(token), expires_at: Time.current..)&.operator
    end
  end
end
