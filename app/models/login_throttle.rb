# == Schema Information
#
# Table name: login_throttles
#
#  id                :integer          not null, primary key
#  attempts          :integer          default(0), not null
#  client_hash       :string           not null
#  window_started_at :datetime         not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_login_throttles_on_client_hash  (client_hash) UNIQUE
#
class LoginThrottle < ApplicationRecord
  validates :client_hash, :window_started_at, presence: true
end
