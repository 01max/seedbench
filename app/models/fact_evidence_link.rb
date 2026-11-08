# == Schema Information
#
# Table name: fact_evidence_links
#
#  id               :integer          not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  evidence_item_id :bigint           not null
#  release_id       :integer          not null
#  reviewed_fact_id :bigint           not null
#
# Indexes
#
#  idx_on_reviewed_fact_id_evidence_item_id_4b9b4ea960  (reviewed_fact_id,evidence_item_id) UNIQUE
#  index_fact_evidence_links_on_release_id              (release_id)
#  index_fact_evidence_links_on_release_id_and_id       (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [release_id, evidence_item_id]  ([release_id, evidence_item_id] => evidence_items[release_id, id])
#  [release_id, reviewed_fact_id]  ([release_id, reviewed_fact_id] => reviewed_facts[release_id, id])
#  release_id                      (release_id => releases.id)
#
class FactEvidenceLink < ApplicationRecord
  belongs_to :release
  belongs_to :reviewed_fact, foreign_key: [ :release_id, :reviewed_fact_id ], primary_key: [ :release_id, :id ], inverse_of: :fact_evidence_links
  belongs_to :evidence_item, foreign_key: [ :release_id, :evidence_item_id ], primary_key: [ :release_id, :id ], inverse_of: :fact_evidence_links
  attr_readonly :release_id, :reviewed_fact_id, :evidence_item_id
end
