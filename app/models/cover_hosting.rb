class CoverHosting < ApplicationRecord
  belongs_to :release
  belongs_to :cover_revision, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_hostings
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :cover_hostings
  attr_readonly :release_id, :cover_revision_id, :provider_connection_id, :provider_role, :direct_url, :media_type, :width, :height, :verified_at
end
