class DuplicateCheck < ApplicationRecord
  has_many :duplicate_decisions, foreign_key: [ :release_id, :duplicate_check_id ], primary_key: [ :release_id, :id ], inverse_of: :duplicate_check, dependent: :restrict_with_exception
  belongs_to :release
  attr_readonly :release_id, :input_revision, :query, :candidates, :searched_at
end
