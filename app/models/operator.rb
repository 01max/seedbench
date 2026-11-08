# == Schema Information
#
# Table name: operators
#
#  id                 :integer          not null, primary key
#  encrypted_password :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Operator < ApplicationRecord
  devise :database_authenticatable, :validatable, :timeoutable
  validate :password_fits_bcrypt

  def self.find_for_database_authentication(_conditions)
    find_by(id: 1)
  end

  protected

  def email_required?
    false
  end

  def devise_will_save_change_to_email?
    false
  end

  private

  def password_fits_bcrypt
    errors.add(:password, :too_long, count: 72) if password && password.bytesize > 72
  end
end
