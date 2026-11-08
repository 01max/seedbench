# == Schema Information
#
# Table name: remote_snapshots
#
#  id                     :integer          not null, primary key
#  base_content           :json             not null
#  kind                   :string           not null
#  local_revision         :integer          not null
#  observed_at            :datetime         not null
#  provider_role          :string           default("publishing"), not null
#  remote_content         :json             not null
#  remote_deleted         :boolean          default(FALSE), not null
#  remote_revision        :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#  remote_id              :string           not null
#
# Indexes
#
#  index_remote_snapshots_on_release_id         (release_id)
#  index_remote_snapshots_on_release_id_and_id  (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  release_id                               (release_id => releases.id)
#
class RemoteSnapshot < ApplicationRecord
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :remote_snapshots
  attr_readonly :release_id, :provider_connection_id, :provider_role, :kind, :remote_id, :remote_revision, :local_revision, :base_content, :remote_content, :remote_deleted, :observed_at
end
