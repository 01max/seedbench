# == Schema Information
#
# Table name: content_revisions
#
#  id                      :integer          not null, primary key
#  body                    :text             not null
#  dependencies            :json             not null
#  input_revision          :integer          not null
#  kind                    :string           not null
#  number                  :integer          not null
#  origin                  :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  cover_revision_id       :bigint
#  payload_revision_id     :bigint
#  preparation_revision_id :bigint
#  release_id              :integer          not null
#
# Indexes
#
#  index_content_revisions_on_release_id                      (release_id)
#  index_content_revisions_on_release_id_and_id               (release_id,id) UNIQUE
#  index_content_revisions_on_release_id_and_kind_and_number  (release_id,kind,number) UNIQUE
#
# Foreign Keys
#
#  [release_id, cover_revision_id]        ([release_id, cover_revision_id] => cover_revisions[release_id, id])
#  [release_id, payload_revision_id]      ([release_id, payload_revision_id] => payload_revisions[release_id, id])
#  [release_id, preparation_revision_id]  ([release_id, preparation_revision_id] => preparation_revisions[release_id, id])
#  release_id                             (release_id => releases.id)
#
class ContentRevision < ApplicationRecord
  belongs_to :release
  belongs_to :payload_revision, foreign_key: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :content_revisions
  belongs_to :preparation_revision, foreign_key: [ :release_id, :preparation_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :content_revisions
  belongs_to :cover_revision, foreign_key: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ], optional: true, inverse_of: :content_revisions
  attr_readonly :release_id, :payload_revision_id, :preparation_revision_id, :cover_revision_id, :kind, :number, :body, :origin, :input_revision, :dependencies
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
