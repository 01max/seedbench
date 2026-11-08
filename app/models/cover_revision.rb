class CoverRevision < ApplicationRecord
  has_many :cover_hostings, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_revision, dependent: :restrict_with_exception
  has_many :content_revisions, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_revision, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :cover_revisions
  attr_readonly :release_id, :payload_revision_id, :number, :source_kind, :source_locator, :width, :height, :edition_evidence
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
