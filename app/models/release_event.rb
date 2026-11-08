# == Schema Information
#
# Table name: release_events
#
#  id             :integer          not null, primary key
#  actor          :string           not null
#  data           :json             not null
#  input_revision :integer          not null
#  name           :string           not null
#  occurred_at    :datetime         not null
#  sequence       :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  release_id     :integer          not null
#
# Indexes
#
#  index_release_events_on_release_id               (release_id)
#  index_release_events_on_release_id_and_id        (release_id,id) UNIQUE
#  index_release_events_on_release_id_and_sequence  (release_id,sequence) UNIQUE
#
# Foreign Keys
#
#  release_id  (release_id => releases.id)
#
class ReleaseEvent < ApplicationRecord
  belongs_to :release
  attr_readonly :release_id, :sequence, :name, :actor, :input_revision, :data, :occurred_at
end
