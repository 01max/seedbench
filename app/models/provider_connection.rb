# == Schema Information
#
# Table name: provider_connections
#
#  id                  :integer          not null, primary key
#  check_code          :string
#  check_message       :string
#  check_status        :string           default("untested"), not null
#  checked_at          :datetime
#  credentials         :text
#  credentials_version :integer          default(0), not null
#  endpoint            :string
#  identity_key        :string           not null
#  label               :string           not null
#  options             :json             not null
#  provider            :string           not null
#  role                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_provider_connections_on_role_and_id            (role,id) UNIQUE
#  index_provider_connections_on_role_and_identity_key  (role,identity_key) UNIQUE
#
class ProviderConnection < ApplicationRecord
  serialize :credentials, coder: JSON
  encrypts :credentials
  has_many :cover_hostings, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  has_many :remote_snapshots, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  has_many :ai_runs, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  has_many :provider_assignments, foreign_key: [ :role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_connection, dependent: :restrict_with_exception
  attr_readonly :role, :provider, :identity_key, :endpoint
  validates :role, :provider, :identity_key, :label, presence: true
end
