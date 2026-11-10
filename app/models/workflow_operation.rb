# == Schema Information
#
# Table name: workflow_operations
#
#  id                 :integer          not null, primary key
#  attempt_token      :string
#  attempts           :integer          default(0), not null
#  effect             :string           not null
#  error_code         :string
#  external_reference :json             not null
#  finished_at        :datetime
#  input_revision     :integer          not null
#  kind               :string           not null
#  lease_expires_at   :datetime
#  parameters         :json             not null
#  phase              :string           default("requested"), not null
#  request_key        :string           not null
#  result             :json             not null
#  started_at         :datetime
#  state              :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  release_id         :integer          not null
#
# Indexes
#
#  index_workflow_operations_on_release_id                  (release_id)
#  index_workflow_operations_on_release_id_and_id           (release_id,id) UNIQUE
#  index_workflow_operations_on_release_id_and_request_key  (release_id,request_key) UNIQUE
#  index_workflow_operations_on_state_and_lease_expires_at  (state,lease_expires_at)
#
# Foreign Keys
#
#  release_id  (release_id => releases.id)
#
class WorkflowOperation < ApplicationRecord
  has_many :cover_uploads, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :workflow_operation, dependent: :restrict_with_exception
  has_many :payload_moves, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :workflow_operation, dependent: :restrict_with_exception
  has_one :ai_run, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :workflow_operation, dependent: :restrict_with_exception
  belongs_to :release
  has_one :dispatch_intent, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :workflow_operation, dependent: :restrict_with_exception
  attr_readonly :release_id, :kind, :request_key, :effect, :input_revision, :parameters
  validates :kind, :request_key, format: { with: /\A[a-zA-Z0-9_-]{1,80}\z/ }
  validates :input_revision, :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effect, inclusion: { in: %w[local remote filesystem] }
  validates :state, inclusion: { in: %w[pending running succeeded failed stale outcome_unknown] }
end
