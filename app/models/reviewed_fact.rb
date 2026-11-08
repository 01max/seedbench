# == Schema Information
#
# Table name: reviewed_facts
#
#  id                  :integer          not null, primary key
#  actor               :string           not null
#  field               :string           not null
#  number              :integer          not null
#  reviewed_at         :datetime         not null
#  value               :json             not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payload_revision_id :bigint           not null
#  release_id          :integer          not null
#
# Indexes
#
#  index_reviewed_facts_on_release_id                       (release_id)
#  index_reviewed_facts_on_release_id_and_field_and_number  (release_id,field,number) UNIQUE
#  index_reviewed_facts_on_release_id_and_id                (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [release_id, payload_revision_id]  ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  release_id                         (release_id => releases.id)
#
class ReviewedFact < ApplicationRecord
  has_many :fact_evidence_links, foreign_key: [ :release_id, :reviewed_fact_id ], primary_key: [ :release_id, :id ], inverse_of: :reviewed_fact, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :reviewed_facts
  attr_readonly :release_id, :payload_revision_id, :field, :number, :value, :actor, :reviewed_at
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
