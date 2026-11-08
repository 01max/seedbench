# == Schema Information
#
# Table name: login_sessions
#
#  id           :integer          not null, primary key
#  expires_at   :datetime         not null
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  operator_id  :integer          not null
#
# Indexes
#
#  index_login_sessions_on_operator_id   (operator_id)
#  index_login_sessions_on_token_digest  (token_digest) UNIQUE
#
# Foreign Keys
#
#  operator_id  (operator_id => operators.id)
#
class LoginSession < ApplicationRecord
  belongs_to :operator
  validates :token_digest, :expires_at, presence: true
end
