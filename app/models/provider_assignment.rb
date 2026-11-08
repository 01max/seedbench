# == Schema Information
#
# Table name: provider_assignments
#
#  id                     :integer          not null, primary key
#  assigned_at            :datetime
#  role                   :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint
#  release_id             :integer          not null
#
# Indexes
#
#  index_provider_assignments_on_release_id           (release_id)
#  index_provider_assignments_on_release_id_and_id    (release_id,id) UNIQUE
#  index_provider_assignments_on_release_id_and_role  (release_id,role) UNIQUE
#
# Foreign Keys
#
#  [role, provider_connection_id]  ([role, provider_connection_id] => provider_connections[role, id])
#  release_id                      (release_id => releases.id)
#
class ProviderAssignment < ApplicationRecord
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :role, :provider_connection_id ], primary_key: [ :role, :id ], optional: true, inverse_of: :provider_assignments
end
