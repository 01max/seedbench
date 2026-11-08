Devise.setup do |config|
  require "devise/orm/active_record"

  # Devise needs identifier metadata for errors; Operator always selects account 1.
  config.authentication_keys = { id: false }
  config.http_authenticatable = false
  config.paranoid = true
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 12..72
  config.timeout_in = 12.hours
  config.lock_strategy = :failed_attempts
  config.maximum_attempts = 10
  config.unlock_strategy = :time
  config.unlock_in = 15.minutes
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other
end
