# == Schema Information
#
# Table name: findings
#
#  id                  :integer          not null, primary key
#  code                :string           not null
#  data                :json             not null
#  input_revision      :integer          not null
#  message             :text             not null
#  number              :integer          not null
#  severity            :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payload_revision_id :bigint           not null
#  release_id          :integer          not null
#
# Indexes
#
#  index_findings_on_release_id                      (release_id)
#  index_findings_on_release_id_and_code_and_number  (release_id,code,number) UNIQUE
#  index_findings_on_release_id_and_id               (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [release_id, payload_revision_id]  ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  release_id                         (release_id => releases.id)
#
class Finding < ApplicationRecord
  has_many :finding_acknowledgements, foreign_key: [ :release_id, :finding_id ], primary_key: [ :release_id, :id ], inverse_of: :finding, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :findings
  attr_readonly :release_id, :payload_revision_id, :code, :number, :severity, :message, :input_revision, :data
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
