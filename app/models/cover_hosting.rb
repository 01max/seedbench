# == Schema Information
#
# Table name: cover_hostings
#
#  id                     :integer          not null, primary key
#  direct_url             :string           not null
#  height                 :integer          not null
#  media_type             :string           not null
#  provider_role          :string           default("image_host"), not null
#  verified_at            :datetime         not null
#  width                  :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  cover_revision_id      :bigint           not null
#  provider_connection_id :bigint           not null
#  release_id             :integer          not null
#
# Indexes
#
#  index_cover_hostings_on_release_id         (release_id)
#  index_cover_hostings_on_release_id_and_id  (release_id,id) UNIQUE
#
# Foreign Keys
#
#  [provider_role, provider_connection_id]  ([provider_role, provider_connection_id] => provider_connections[role, id])
#  [release_id, cover_revision_id]          ([release_id, cover_revision_id] => cover_revisions[release_id, id])
#  release_id                               (release_id => releases.id)
#
class CoverHosting < ApplicationRecord
  belongs_to :release
  belongs_to :cover_revision, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], inverse_of: :cover_hostings
  belongs_to :provider_connection, foreign_key: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ], inverse_of: :cover_hostings
  attr_readonly :release_id, :cover_revision_id, :provider_connection_id, :provider_role, :direct_url, :media_type, :width, :height, :verified_at
end
