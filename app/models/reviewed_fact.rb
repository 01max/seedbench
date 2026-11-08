class ReviewedFact < ApplicationRecord
  has_many :fact_evidence_links, foreign_key: [ :release_id, :reviewed_fact_id ], primary_key: [ :release_id, :id ], inverse_of: :reviewed_fact, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :reviewed_facts
  attr_readonly :release_id, :payload_revision_id, :field, :number, :value, :actor, :reviewed_at
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
