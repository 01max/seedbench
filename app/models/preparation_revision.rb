class PreparationRevision < ApplicationRecord
  has_many :content_revisions, foreign_key: [ :release_id, :preparation_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :preparation_revision, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :preparation_revisions
  attr_readonly :release_id, :number, :payload_revision_id, :release_name, :payload_name, :torrent_locator, :torrent_info_hash, :payload_sha256, :payload_size_bytes, :policy_version, :prepared_at
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
