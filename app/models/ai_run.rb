# == Schema Information
#
# Table name: ai_runs
#
#  id                     :integer          not null, primary key
#  error_code             :string
#  evidence_keys          :json             not null
#  input_revision         :integer          not null
#  model                  :string           not null
#  prompt_version         :string           not null
#  provider_role          :string           default("ai"), not null
#  purpose                :string           not null
#  request                :json             not null
#  result                 :json
#  status                 :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#  workflow_operation_id  :bigint
#
# Indexes
#
#  index_ai_runs_on_release_id             (release_id)
#  index_ai_runs_on_release_id_and_id      (release_id,id) UNIQUE
#  index_ai_runs_on_workflow_operation_id  (workflow_operation_id) UNIQUE
#  one_active_ai_run                       (release_id,purpose) UNIQUE WHERE workflow_operation_id IS NOT NULL AND status IN ('pending', 'running')
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  [release_id, workflow_operation_id]      ([release_id, workflow_operation_id] => workflow_operations[release_id, id])
#  release_id                               (release_id => releases.id)
#
class AiRun < ApplicationRecord
  belongs_to :workflow_operation, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :ai_run
  attr_readonly :release_id, :provider_connection_id, :provider_role, :input_revision, :purpose, :prompt_version, :model, :evidence_keys, :request, :workflow_operation_id
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :ai_runs
end
