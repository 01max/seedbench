class PayloadRevision < ApplicationRecord
  has_many :preparation_revisions, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
  has_many :evidence_items, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
  has_many :reviewed_facts, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
  has_many :findings, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
  has_many :cover_revisions, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
  has_many :content_revisions, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
  belongs_to :release
  validates :number, numericality: { only_integer: true, greater_than: 0 }
  attr_readonly :release_id, :number, :original_filename, :format, :sha256, :size_bytes
  validates :original_filename, :locator, presence: true
  validates :format, inclusion: { in: %w[epub pdf mobi] }
  validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :size_bytes, numericality: { only_integer: true, greater_than: 0 }
end
