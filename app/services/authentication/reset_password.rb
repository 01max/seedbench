module Authentication
  class ResetPassword
    class InvalidPassword < StandardError; end

    def self.call(password:, password_confirmation:)
      candidate = Operator.new(id: 1, password: password, password_confirmation: password_confirmation)
      raise InvalidPassword, "Utilisez au moins 12 caractères, au plus 72 octets, avec une confirmation identique." unless candidate.valid?

      Operator.transaction do
        operator = Operator.find_or_initialize_by(id: 1)
        operator.password_digest = candidate.password_digest
        operator.save!
        operator.login_sessions.delete_all
        LoginThrottle.delete_all
        operator
      end
    end
  end
end
