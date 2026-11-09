abort 'Use interactive input without arguments.' unless ARGV.empty?

# Docker can forward macOS SIGINFO as Linux SIGIO during terminal input.
Signal.trap('IO', 'IGNORE') if Signal.list.key?('IO')

begin
  Authentication::PasswordConsole.call
rescue Authentication::PasswordConsole::InputError => error
  abort error.message
end
