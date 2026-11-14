module Seeding
  # Marks initial seeding uncertain when an interrupted attempt has no terminal outcome.
  class Interrupted
    def self.call(operation:)
      release = operation.release
      return if %w[succeeded failed].include?(release.seeding_state)

      release.update!(seeding_state: 'unknown')
    end
  end
end
