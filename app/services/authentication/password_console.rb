require 'io/console'

module Authentication
  class PasswordConsole
    class InputError < StandardError; end

    class << self
      def call(input: $stdin, output: $stderr)
        raise InputError, I18n.t('messages.authentication.password_console.un_terminal_interactif_est_requis_aucun') unless input.tty?

        password = read(input, output, prompt: I18n.t('messages.authentication.password_console.new_password'))
        confirmation = read(input, output, prompt: I18n.t('messages.authentication.password_console.confirm_password'))
        save_password(password, confirmation)
        output.puts I18n.t('messages.authentication.password_console.password_saved')
      rescue EOFError, Interrupt
        raise InputError, I18n.t('messages.authentication.password_console.saisie_interrompue_le_mot_de_passe')
      end

      private

      def save_password(password, confirmation)
        Operator.transaction do
          operator = Operator.find_or_initialize_by(id: 1)
          operator.update!(password: password, password_confirmation: confirmation)
          operator.unlock_access!
        end
      rescue ActiveRecord::RecordInvalid
        raise InputError, I18n.t('messages.authentication.password_console.utilisez_au_moins_12_caracteres_au')
      end

      def read(input, output, prompt:)
        value = input.noecho do
          output.print prompt
          output.flush
          input.gets
        end
        output.puts
        raise EOFError unless value

        value.chomp
      end
    end
  end
end
