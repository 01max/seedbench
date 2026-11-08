# == Schema Information
#
# Table name: cover_revisions
#
#  id                  :integer          not null, primary key
#  edition_evidence    :json             not null
#  height              :integer
#  number              :integer          not null
#  source_kind         :string           not null
#  source_locator      :string           not null
#  width               :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payload_revision_id :bigint
#  release_id          :integer          not null
#
# Indexes
#
#  index_cover_revisions_on_release_id             (release_id)
#  index_cover_revisions_on_release_id_and_id      (release_id,id) UNIQUE
#  index_cover_revisions_on_release_id_and_number  (release_id,number) UNIQUE
#
# Foreign Keys
#
#  [release_id, payload_revision_id]  ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  release_id                         (release_id => releases.id)
#
class CoverRevision < ApplicationRecord
  has_many :cover_hostings, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_revision, dependent: :restrict_with_exception
  has_many :content_revisions, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_revision, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :cover_revisions
  attr_readonly :release_id, :payload_revision_id, :number, :source_kind, :source_locator, :width, :height, :edition_evidence
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
