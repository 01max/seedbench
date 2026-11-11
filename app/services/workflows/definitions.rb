module Workflows
  class Definitions
    class UnsupportedKind < StandardError; end
    Definition = Data.define(:compute, :apply, :effect, :stale, :recoverable, :retain_stale) do
      def initialize(compute:, apply:, effect:, stale: nil, recoverable: false, retain_stale: false)
        super
      end
    end
    ENTRIES = {
      'publish' => Definition.new(compute: Publications::Submit, apply: Publications::Record, effect: 'remote', retain_stale: true),
      'draft_delete' => Definition.new(compute: Drafts::Write, apply: Drafts::Record, effect: 'remote', stale: Drafts::Cancel, retain_stale: true),
      'draft_write' => Definition.new(compute: Drafts::Write, apply: Drafts::Record, effect: 'remote', stale: Drafts::Cancel, retain_stale: true),
      'ai_assessment' => Definition.new(compute: Ai::Compute, apply: Ai::Record, effect: 'local', stale: Ai::Cancel, retain_stale: true),
      'ai_prose' => Definition.new(compute: Ai::Compute, apply: Ai::Record, effect: 'local', stale: Ai::Cancel, retain_stale: true),
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
