# == Schema Information
#
# Table name: payload_moves
#
#  id                    :integer          not null, primary key
#  destination_locator   :string           not null
#  root_device           :bigint           not null
#  root_inode            :bigint           not null
#  source_device         :bigint           not null
#  source_inode          :bigint           not null
#  source_locator        :string           not null
#  state                 :string           default("reserved"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  payload_revision_id   :bigint           not null
#  release_id            :integer          not null
#  workflow_operation_id :bigint           not null
#
# Indexes
#
#  active_payload_destination                    (destination_locator) UNIQUE WHERE state IN ('reserved', 'moved')
#  index_payload_moves_on_release_id             (release_id)
#  index_payload_moves_on_workflow_operation_id  (workflow_operation_id) UNIQUE
#
# Foreign Keys
#
#  [release_id, payload_revision_id]    ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  [release_id, workflow_operation_id]  ([release_id, workflow_operation_id] => workflow_operations[release_id, id])
#  release_id                           (release_id => releases.id)
#
class PayloadMove < ApplicationRecord
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_moves
  belongs_to :workflow_operation, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :payload_moves
  attr_readonly :release_id, :payload_revision_id, :workflow_operation_id, :source_locator, :destination_locator,
    :source_device, :source_inode, :root_device, :root_inode
  validates :state, inclusion: { in: %w[reserved moved completed cancelled] }
end
