module Workflows
  class Definitions
    class UnsupportedKind < StandardError; end
    Definition = Data.define(:compute, :apply, :effect, :stale, :recoverable) do
      def initialize(compute:, apply:, effect:, stale: nil, recoverable: false)
        super
      end
    end
    ENTRIES = {
      'duplicate_search' => Definition.new(compute: Duplicates::Search, apply: Duplicates::Record, effect: 'local'),
      'preparation' => Definition.new(compute: Preparation::Build, apply: Preparation::Record, effect: 'filesystem', stale: Preparation::Stale, recoverable: true),
      'inspection' => Definition.new(compute: Ebooks::Inspect, apply: Ebooks::Record, effect: 'local', stale: Ebooks::Refresh),
      'edition_lookup' => Definition.new(compute: Ebooks::Lookup, apply: Ebooks::RecordLookup, effect: 'local')
    }.freeze

    def self.fetch(kind)
      ENTRIES.fetch(kind) { raise UnsupportedKind, I18n.t('messages.workflows.definitions.this_operation_kind_is_not_implemented') }
    end
  end
end
