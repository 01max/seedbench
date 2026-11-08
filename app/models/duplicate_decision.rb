class DuplicateDecision < ApplicationRecord
  belongs_to :release
  belongs_to :duplicate_check, foreign_key: [ :release_id, :duplicate_check_id ], primary_key: [ :release_id, :id ], inverse_of: :duplicate_decisions
  attr_readonly :release_id, :duplicate_check_id, :candidate_key, :decision, :reason, :actor, :reviewed_at
end
