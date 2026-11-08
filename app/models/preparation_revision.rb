# == Schema Information
#
# Table name: preparation_revisions
#
#  id                  :integer          not null, primary key
#  number              :integer          not null
#  payload_name        :string           not null
#  payload_sha256      :string           not null
#  payload_size_bytes  :bigint           not null
#  policy_version      :string           not null
#  prepared_at         :datetime         not null
#  release_name        :string           not null
#  torrent_info_hash   :string           not null
#  torrent_locator     :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  payload_revision_id :bigint           not null
#  release_id          :integer          not null
#
# Indexes
#
#  index_preparation_revisions_on_release_id             (release_id)
#  index_preparation_revisions_on_release_id_and_id      (release_id,id) UNIQUE
#  index_preparation_revisions_on_release_id_and_number  (release_id,number) UNIQUE
#
# Foreign Keys
#
#  [release_id, payload_revision_id, payload_sha256, payload_size_bytes]  ([release_id, payload_revision_id, payload_sha256, payload_size_bytes] => payload_revisions[release_id, id, sha256, size_bytes])
#  [release_id, payload_revision_id]                                      ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  release_id                                                             (release_id => releases.id)
#
class PreparationRevision < ApplicationRecord
  has_many :content_revisions, foreign_key: [ :release_id, :preparation_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :preparation_revision, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :preparation_revisions
  attr_readonly :release_id, :number, :payload_revision_id, :release_name, :payload_name, :torrent_locator, :torrent_info_hash, :payload_sha256, :payload_size_bytes, :policy_version, :prepared_at
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
