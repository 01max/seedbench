class EvidenceItem < ApplicationRecord
  has_many :fact_evidence_links, foreign_key: [ :release_id, :evidence_item_id ], primary_key: [ :release_id, :id ], inverse_of: :evidence_item, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :evidence_items
  attr_readonly :release_id, :payload_revision_id, :evidence_key, :kind, :source, :captured_at, :input_revision, :data
end
