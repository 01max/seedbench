# == Schema Information
#
# Table name: draft_links
#
#  id                     :integer          not null, primary key
#  provider_role          :string           default("publishing"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#  remote_id              :string           not null
#
# Indexes
#
#  index_draft_links_on_provider_connection_id_and_remote_id  (provider_connection_id,remote_id) UNIQUE
#  index_draft_links_on_release_id                            (release_id) UNIQUE
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  release_id                               (release_id => releases.id)
#
class DraftLink < ApplicationRecord
  belongs_to :release
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :draft_links
  attr_readonly :provider_connection_id, :provider_role, :remote_id
end
