# == Schema Information
#
# Table name: content_proposals
#
#  id             :integer          not null, primary key
#  bases          :json             not null
#  bodies         :json             not null
#  dependencies   :json             not null
#  input_revision :integer          not null
#  kind           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  release_id     :integer          not null
#
# Indexes
#
#  index_content_proposals_on_release_id  (release_id)
#
# Foreign Keys
#
#  release_id  (release_id => releases.id)
#
class ContentProposal < ApplicationRecord
  belongs_to :release
  attr_readonly :release_id, :kind, :input_revision, :bodies, :dependencies, :bases
  validates :kind, inclusion: { in: %w[replacement cover] }
end
