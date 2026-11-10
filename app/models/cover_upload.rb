# == Schema Information
#
# Table name: cover_uploads
#
#  id                     :integer          not null, primary key
#  direct_url             :string
#  failure_code           :string
#  page_url               :string
#  provider_role          :string           default("image_host"), not null
#  source_sha256          :string           not null
#  state                  :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  cover_revision_id      :bigint           not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#  workflow_operation_id  :bigint           not null
#
# Indexes
#
#  index_cover_uploads_on_release_id             (release_id)
#  index_cover_uploads_on_workflow_operation_id  (workflow_operation_id) UNIQUE
#  one_uncertain_cover_upload                    (release_id,cover_revision_id,provider_connection_id) UNIQUE WHERE state IN ('pending', 'outcome_unknown')
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  [release_id, cover_revision_id]          ([release_id, cover_revision_id] => cover_revisions[release_id, id])
#  [release_id, workflow_operation_id]      ([release_id, workflow_operation_id] => workflow_operations[release_id, id])
#  release_id                               (release_id => releases.id)
#
class CoverUpload < ApplicationRecord
  belongs_to :release
  belongs_to :workflow_operation, foreign_key: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_uploads
  belongs_to :cover_revision, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_uploads
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :cover_uploads
  attr_readonly :release_id, :workflow_operation_id, :cover_revision_id, :provider_connection_id, :provider_role, :source_sha256
  validates :state, inclusion: { in: %w[pending uploaded verified failed outcome_unknown] }
end
