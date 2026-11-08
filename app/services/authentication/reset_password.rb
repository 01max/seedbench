module Authentication
  class ResetPassword
    class InvalidPassword < StandardError; end

    def self.call(password:, password_confirmation:)
      candidate = Operator.new(id: 1, password: password, password_confirmation: password_confirmation)
      raise InvalidPassword, "Utilisez au moins 12 caractères, au plus 72 octets, avec une confirmation identique." unless candidate.valid?

      Operator.transaction do
        operator = Operator.find_by(id: 1) || candidate
        operator.encrypted_password = candidate.encrypted_password
        operator.save!
        ActiveRecord::SessionStore::Session.delete_all
        operator.unlock_access!
        operator
      end
    end
  end
end
