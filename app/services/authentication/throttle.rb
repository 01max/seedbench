require "digest"

module Authentication
  class Throttle
    class RateLimited < StandardError; end
    WINDOW = 15.minutes
    LIMIT = 10

    def self.check!(ip:)
      LoginThrottle.transaction do
        LoginThrottle.where(window_started_at: ...1.day.ago).delete_all
        record = LoginThrottle.find_or_initialize_by(client_hash: Digest::SHA256.hexdigest(ip.to_s))
        record.assign_attributes(attempts: 0, window_started_at: Time.current) if !record.persisted? || record.window_started_at <= WINDOW.ago
        raise RateLimited, "Trop de tentatives. Réessayez dans 15 minutes." if record.attempts >= LIMIT

        record.attempts += 1
        record.save!
      end
    end
  end
end
