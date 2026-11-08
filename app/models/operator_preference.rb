# == Schema Information
#
# Table name: operator_preferences
#
#  id           :integer          not null, primary key
#  automatic_ai :boolean          default(TRUE), not null
#  revision     :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class OperatorPreference < ApplicationRecord
  validates :automatic_ai, inclusion: { in: [ true, false ] }
  validates :revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
