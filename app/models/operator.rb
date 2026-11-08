# == Schema Information
#
# Table name: operators
#
#  id              :integer          not null, primary key
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Operator < ApplicationRecord
  has_secure_password
  has_many :login_sessions, dependent: :delete_all
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
end
