class FindingAcknowledgement < ApplicationRecord
  belongs_to :release
  belongs_to :finding, foreign_key: [ :release_id, :finding_id ], primary_key: [ :release_id, :id ], inverse_of: :finding_acknowledgements
  attr_readonly :release_id, :finding_id, :acknowledged, :actor, :note
end
