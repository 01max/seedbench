class ProviderConnection < ApplicationRecord
  has_many :cover_hostings, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  has_many :remote_snapshots, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  has_many :ai_runs, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  has_many :provider_assignments, foreign_key: [ :role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  attr_readonly :role, :provider, :identity_key, :endpoint
  validates :role, :provider, :identity_key, :label, presence: true
end
