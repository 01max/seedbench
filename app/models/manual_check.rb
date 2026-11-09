# == Schema Information
#
# Table name: manual_checks
#
#  id             :integer          not null, primary key
#  actor          :string           not null
#  checked        :boolean          default(FALSE), not null
#  input_revision :integer          not null
#  key            :string           not null
#  number         :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  release_id     :integer          not null
#
# Indexes
#
#  index_manual_checks_on_release_id                     (release_id)
#  index_manual_checks_on_release_id_and_key_and_number  (release_id,key,number) UNIQUE
#
# Foreign Keys
#
#  release_id  (release_id => releases.id)
#
class ManualCheck < ApplicationRecord
  belongs_to :release
  attr_readonly :release_id, :key, :number, :checked, :input_revision, :actor
  validates :key, inclusion: { in: %w[edition_review text_review] }
  validates :number, numericality: { only_integer: true, greater_than: 0 }
end
