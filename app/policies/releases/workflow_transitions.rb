module Releases
  class WorkflowTransitions
    NEXT_STATES = {
      'inspection' => { 'pending' => %w[running], 'running' => %w[succeeded failed], 'succeeded' => %w[running], 'failed' => %w[running] },
      'preparation' => { 'unprepared' => %w[running], 'running' => %w[prepared failed], 'prepared' => %w[stale], 'stale' => %w[running], 'failed' => %w[running] },
      'draft' => { 'unlinked' => %w[synced], 'synced' => %w[conflicted missing], 'conflicted' => %w[synced missing], 'missing' => %w[unlinked synced] },
      'publication' => { 'unpublished' => %w[submitting], 'submitting' => %w[published outcome_unknown failed], 'outcome_unknown' => %w[published failed], 'failed' => %w[submitting], 'published' => [] },
      'seeding' => { 'not_started' => %w[checking], 'checking' => %w[seeding failed unknown], 'seeding' => %w[succeeded failed unknown], 'failed' => %w[checking], 'unknown' => %w[checking], 'succeeded' => [] }
    }.freeze

    def self.allowed?(dimension:, from:, to:)
      NEXT_STATES.fetch(dimension, {}).fetch(from, []).include?(to)
    end
  end
end
