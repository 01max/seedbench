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
#  result                 :json
#  status                 :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#
# Indexes
#
#  index_ai_runs_on_release_id         (release_id)
#  index_ai_runs_on_release_id_and_id  (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  release_id                               (release_id => releases.id)
#
class AiRun < ApplicationRecord
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :ai_runs
end
