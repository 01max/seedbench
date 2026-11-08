class WorkflowOperation < ApplicationRecord
  belongs_to :release
  has_one :dispatch_intent, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :workflow_operation, dependent: :restrict_with_exception
  attr_readonly :release_id, :kind, :request_key, :effect, :input_revision, :parameters
  validates :kind, :request_key, format: { with: /\A[a-zA-Z0-9_-]{1,80}\z/ }
  validates :input_revision, :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effect, inclusion: { in: %w[local remote filesystem] }
  validates :state, inclusion: { in: %w[pending running succeeded failed stale outcome_unknown] }
end
