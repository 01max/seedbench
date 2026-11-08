class Release < ApplicationRecord
  has_many :workflow_operations, dependent: :restrict_with_exception
  has_many :dispatch_intents, dependent: :restrict_with_exception
  has_many :payload_revisions, dependent: :restrict_with_exception
  has_many :preparation_revisions, dependent: :restrict_with_exception
  has_many :evidence_items, dependent: :restrict_with_exception
  has_many :reviewed_facts, dependent: :restrict_with_exception
  has_many :fact_evidence_links, dependent: :restrict_with_exception
  has_many :findings, dependent: :restrict_with_exception
  has_many :finding_acknowledgements, dependent: :restrict_with_exception
  has_many :cover_revisions, dependent: :restrict_with_exception
  has_many :cover_hostings, dependent: :restrict_with_exception
  has_many :content_revisions, dependent: :restrict_with_exception
  has_many :duplicate_checks, dependent: :restrict_with_exception
  has_many :duplicate_decisions, dependent: :restrict_with_exception
  has_many :remote_snapshots, dependent: :restrict_with_exception
  has_many :ai_runs, dependent: :restrict_with_exception
  has_many :provider_assignments, dependent: :restrict_with_exception
  has_many :release_events, dependent: :restrict_with_exception
  validates :inspection_state, inclusion: { in: %w[pending running succeeded failed] }
  validates :preparation_state, inclusion: { in: %w[unprepared running prepared stale failed] }
  validates :draft_state, inclusion: { in: %w[unlinked synced conflicted missing] }
  validates :publication_state, inclusion: { in: %w[unpublished submitting published outcome_unknown failed] }
  validates :seeding_state, inclusion: { in: %w[not_started checking seeding succeeded failed unknown] }
  validates :input_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
