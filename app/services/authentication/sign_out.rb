require "digest"

module Authentication
  class SignOut
    def self.call(token:)
      LoginSession.where(token_digest: Digest::SHA256.hexdigest(token.to_s)).delete_all
    end
  end
end
