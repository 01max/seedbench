class RemoteSnapshot < ApplicationRecord
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :remote_snapshots
  attr_readonly :release_id, :provider_connection_id, :provider_role, :kind, :remote_id, :remote_revision, :local_revision, :base_content, :remote_content, :remote_deleted, :observed_at
end
