class DispatchIntent < ApplicationRecord
  belongs_to :release
  belongs_to :workflow_operation, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :dispatch_intent
  validates :state, inclusion: { in: %w[pending dispatching dispatched] }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
