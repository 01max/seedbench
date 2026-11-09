module Ebooks
  class ProcessBudget
    class Exceeded < StandardError; end

    def self.call(pid:, directory:, seconds: 90)
      new(directory, seconds).wait(pid)
    end

    def initialize(directory, seconds)
      @directory = directory
      @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    end

    def wait(pid)
      loop do
        raise Exceeded if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @deadline

        check_directory!
        completed = Process.waitpid2(pid, Process::WNOHANG)
        return completed.last if completed

        sleep 0.05
      end
    end

    private

    def check_directory!
      @entries, @bytes = 0, 0
      walk(@directory)
    end

    def walk(directory, depth = 0)
      raise Exceeded if depth > 16

      Dir.each_child(directory) do |name|
        path = directory.join(name)
        stat = path.lstat
        account(stat)

        walk(path, depth + 1) if stat.directory?
      rescue Errno::ENOENT
        next
      end
    end
    def account(stat)
      @entries += 1
      @bytes += stat.size unless stat.directory? || stat.symlink?
      raise Exceeded if @entries > 512 || @bytes > 64.megabytes
    end
  end
end
