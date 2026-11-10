# == Schema Information
#
# Table name: draft_writes
#
#  id                     :integer          not null, primary key
#  action                 :string           not null
#  baseline_ids           :json             not null
#  body                   :json
#  error_code             :string
#  provider_role          :string           default("publishing"), not null
#  request                :json             not null
#  state                  :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#  remote_id              :string
#  workflow_operation_id  :bigint           not null
#
# Indexes
#
#  index_draft_writes_on_release_id             (release_id)
#  index_draft_writes_on_workflow_operation_id  (workflow_operation_id) UNIQUE
#  one_active_draft_write                       (release_id) UNIQUE WHERE state IN ('pending', 'sending', 'unknown')
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  [release_id, workflow_operation_id]      ([release_id, workflow_operation_id] => workflow_operations[release_id, id])
#  release_id                               (release_id => releases.id)
#
class DraftWrite < ApplicationRecord
  belongs_to :release
  belongs_to :workflow_operation, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :draft_write
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :draft_writes
  attr_readonly :release_id, :workflow_operation_id, :provider_connection_id, :provider_role, :action, :request
end
