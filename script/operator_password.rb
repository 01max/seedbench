abort "Use interactive input without arguments." unless ARGV.empty?

begin
  Authentication::PasswordConsole.call
rescue Authentication::PasswordConsole::InputError, Authentication::ResetPassword::InvalidPassword => error
  abort error.message
end
