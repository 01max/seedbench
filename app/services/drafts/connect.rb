module Drafts
  # Imports existing drafts when a C411 connection becomes usable and records any import failure on
  # the connection.
  class Connect
    def self.call(connection:)
      return unless connection.provider == 'c411' && !connection.configuration_incomplete?
      Import.call(connection: connection)
    rescue Providers::Failure, Failure => error
      connection.update!(check_status: 'failed', check_code: error.code, check_message: error.message, checked_at: Time.current)
      nil
    end
  end
end
