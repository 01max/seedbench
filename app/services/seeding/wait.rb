module Seeding
  class Wait
    def self.call(seconds:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      loop do
        observed = yield
        return observed if observed

        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return unless remaining.positive?

        sleep([ 1, remaining ].min)
      end
    end
  end
end
