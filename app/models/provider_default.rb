# == Schema Information
#
# Table name: provider_defaults
#
#  id                     :integer          not null, primary key
#  role                   :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint
#
# Indexes
#
#  index_provider_defaults_on_role  (role) UNIQUE
#
# Foreign Keys
#
#  [role, provider_connection_id]  ([role, provider_connection_id] => provider_connections[role, id])
#
class ProviderDefault < ApplicationRecord
  belongs_to :provider_connection, foreign_key: [ :role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :provider_defaults, optional: true
  validates :role, presence: true
end
