class ContentRevision < ApplicationRecord
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :content_revisions
  belongs_to :preparation_revision, foreign_key: [ :release_id, :preparation_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :content_revisions
  belongs_to :cover_revision, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :content_revisions
  attr_readonly :release_id, :payload_revision_id, :preparation_revision_id, :cover_revision_id, :kind, :number, :body, :origin, :input_revision, :dependencies
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
