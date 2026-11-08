# == Schema Information
#
# Table name: finding_acknowledgements
#
#  id           :integer          not null, primary key
#  acknowledged :boolean          default(FALSE), not null
#  actor        :string           not null
#  note         :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  finding_id   :bigint           not null
#  release_id   :integer          not null
#
# Indexes
#
#  index_finding_acknowledgements_on_release_id         (release_id)
#  index_finding_acknowledgements_on_release_id_and_id  (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [release_id, finding_id]  ([release_id, finding_id] => findings[release_id, id])
#  release_id                (release_id => releases.id)
#
class FindingAcknowledgement < ApplicationRecord
  belongs_to :release
  belongs_to :finding, foreign_key: [ :release_id, :finding_id ], primary_key: [ :release_id, :id ], inverse_of: :finding_acknowledgements
  attr_readonly :release_id, :finding_id, :acknowledged, :actor, :note
end
