class ProviderAssignment < ApplicationRecord
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :role, :provider_connection_id ], primary_key: [ :role, :id ], optional: true, inverse_of: :provider_assignments
end
