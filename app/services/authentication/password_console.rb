require "io/console"

module Authentication
  class PasswordConsole
    class InputError < StandardError; end

    def self.call(input: $stdin, output: $stderr)
      raise InputError, "Un terminal interactif est requis; aucun mot de passe ne doit être passé en argument." unless input.tty?

      password = read(input, output, "Nouveau mot de passe : ")
      confirmation = read(input, output, "Confirmez le mot de passe : ")
      save_password(password, confirmation)
      output.puts "Mot de passe enregistré. Toutes les sessions précédentes sont révoquées."
    rescue EOFError, Interrupt
      raise InputError, "Saisie interrompue; le mot de passe reste inchangé."
    end

    def self.save_password(password, confirmation)
      Operator.transaction do
        operator = Operator.find_or_initialize_by(id: 1)
        operator.update!(password: password, password_confirmation: confirmation)
        operator.unlock_access!
      end
    rescue ActiveRecord::RecordInvalid
      raise InputError, "Utilisez au moins 12 caractères, au plus 72 octets, avec une confirmation identique."
    end
    private_class_method :save_password

    def self.read(input, output, prompt)
      value = input.noecho do
        output.print prompt
        output.flush
        input.gets
      end
      output.puts
      raise EOFError unless value

      value.chomp
    end
    private_class_method :read
  end
end
