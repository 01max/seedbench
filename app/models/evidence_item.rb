# == Schema Information
#
# Table name: evidence_items
#
#  id                  :integer          not null, primary key
#  captured_at         :datetime         not null
#  data                :json             not null
#  evidence_key        :string           not null
#  input_revision      :integer          not null
#  kind                :string           not null
#  source              :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payload_revision_id :bigint           not null
#  release_id          :integer          not null
#
# Indexes
#
#  index_evidence_items_on_release_id                   (release_id)
#  index_evidence_items_on_release_id_and_evidence_key  (release_id,evidence_key) UNIQUE
#  index_evidence_items_on_release_id_and_id            (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [release_id, payload_revision_id]  ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  release_id                         (release_id => releases.id)
#
class EvidenceItem < ApplicationRecord
  has_many :fact_evidence_links, foreign_key: [ :release_id, :evidence_item_id ], primary_key: [ :release_id, :id ], inverse_of: :evidence_item, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :evidence_items
  attr_readonly :release_id, :payload_revision_id, :evidence_key, :kind, :source, :captured_at, :input_revision, :data
end
