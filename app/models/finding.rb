class Finding < ApplicationRecord
  has_many :finding_acknowledgements, foreign_key: [ :release_id, :finding_id ], primary_key: [ :release_id, :id ], inverse_of: :finding, dependent: :restrict_with_exception
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :findings
  attr_readonly :release_id, :payload_revision_id, :code, :number, :severity, :message, :input_revision, :data
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
