require_relative 'runtime_preparation'

abort 'Use only disposable runtime verification state' unless ENV['SEEDBENCH_RUNTIME_VERIFICATION'] == '1'
case ARGV.fetch(0)
when 'start' then RuntimePreparation.start
when 'await_rename' then RuntimePreparation.await_rename
when 'recover' then RuntimePreparation.recover
else abort 'Unknown preparation verification mode'
end
