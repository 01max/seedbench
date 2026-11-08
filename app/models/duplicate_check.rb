# == Schema Information
#
# Table name: duplicate_checks
#
#  id             :integer          not null, primary key
#  candidates     :json             not null
#  input_revision :integer          not null
#  query          :json             not null
#  searched_at    :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  release_id     :integer          not null
#
# Indexes
#
#  index_duplicate_checks_on_release_id         (release_id)
#  index_duplicate_checks_on_release_id_and_id  (release_id,id) UNIQUE
#
# Foreign Keys
#
#  release_id  (release_id => releases.id)
#
class DuplicateCheck < ApplicationRecord
  has_many :duplicate_decisions, foreign_key: [ :release_id, :duplicate_check_id ], primary_key: [ :release_id, :id ], inverse_of: :duplicate_check, dependent: :restrict_with_exception
  belongs_to :release
  attr_readonly :release_id, :input_revision, :query, :candidates, :searched_at
end
