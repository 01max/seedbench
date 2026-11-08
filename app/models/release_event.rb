class ReleaseEvent < ApplicationRecord
  belongs_to :release
  attr_readonly :release_id, :sequence, :name, :actor, :input_revision, :data, :occurred_at
end
