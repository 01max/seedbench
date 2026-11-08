class FactEvidenceLink < ApplicationRecord
  belongs_to :release
  belongs_to :reviewed_fact, foreign_key: [ :release_id, :reviewed_fact_id ], primary_key: [ :release_id, :id ], inverse_of: :fact_evidence_links
  belongs_to :evidence_item, foreign_key: [ :release_id, :evidence_item_id ], primary_key: [ :release_id, :id ], inverse_of: :fact_evidence_links
  attr_readonly :release_id, :reviewed_fact_id, :evidence_item_id
end
