# == Schema Information
#
# Table name: dispatch_intents
#
#  id                    :integer          not null, primary key
#  attempts              :integer          default(0), not null
#  claimed_until         :datetime
#  dispatch_token        :string
#  dispatched_at         :datetime
#  error_code            :string
#  state                 :string           default("pending"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  job_id                :string
#  release_id            :integer          not null
#  workflow_operation_id :bigint           not null
#
# Indexes
#
#  index_dispatch_intents_on_release_id               (release_id)
#  index_dispatch_intents_on_state_and_claimed_until  (state,claimed_until)
#  index_dispatch_intents_on_workflow_operation_id    (workflow_operation_id) UNIQUE
#
# Foreign Keys
#
#  [release_id, workflow_operation_id]  ([release_id, workflow_operation_id] => workflow_operations[release_id, id])
#  release_id                           (release_id => releases.id)
#
class DispatchIntent < ApplicationRecord
  belongs_to :release
  belongs_to :workflow_operation, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :dispatch_intent
  validates :state, inclusion: { in: %w[pending dispatching dispatched] }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
