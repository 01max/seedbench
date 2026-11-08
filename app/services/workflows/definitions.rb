module Workflows
  class Definitions
    class UnsupportedKind < StandardError; end
    Definition = Data.define(:compute, :apply, :effect)
    # Feature services add explicit code-owned definitions when their behavior exists.
    ENTRIES = {}.freeze

    def self.fetch(kind)
      ENTRIES.fetch(kind) { raise UnsupportedKind, "This operation kind is not implemented." }
    end
  end
end
