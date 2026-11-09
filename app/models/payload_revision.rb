# == Schema Information
#
# Table name: payload_revisions
#
#  id                :integer          not null, primary key
#  format            :string           not null
#  locator           :string           not null
#  number            :integer          not null
#  original_filename :string           not null
#  sha256            :string           not null
#  size_bytes        :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  release_id        :integer          not null
#
# Indexes
#
#  index_payload_revisions_on_release_id             (release_id)
#  index_payload_revisions_on_release_id_and_id      (release_id,id) UNIQUE
#  index_payload_revisions_on_release_id_and_number  (release_id,number) UNIQUE
#  payload_identity_key                              (release_id,id,sha256,size_bytes) UNIQUE
#
# Foreign Keys
#
#  release_id  (release_id => releases.id)
#
class PayloadRevision < ApplicationRecord
  has_many :payload_moves, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_revision, dependent: :restrict_with_exception
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
