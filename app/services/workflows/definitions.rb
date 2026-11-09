module Workflows
  class Definitions
    class UnsupportedKind < StandardError; end
    Definition = Data.define(:compute, :apply, :effect, :stale) do
      def initialize(compute:, apply:, effect:, stale: nil)
        super
      end
    end
    ENTRIES = {
      "inspection" => Definition.new(compute: Ebooks::Inspect, apply: Ebooks::Record, effect: "local", stale: Ebooks::Refresh)
    }.freeze

    def self.fetch(kind)
      ENTRIES.fetch(kind) { raise UnsupportedKind, "This operation kind is not implemented." }
    end
  end
end
