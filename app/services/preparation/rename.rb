require 'timeout'

module Preparation
  class Rename
    class << self
      def call(source:, destination:)
        return if source == destination

        status = execute(source, destination)
        return if status.success?

        code = { 17 => :collision, 18 => :different_filesystem }.fetch(status.exitstatus, :rename_unavailable)
        raise Failure.new(code)
      end

      private

      def execute(source, destination)
        pid = Process.spawn('python3', '-I', Rails.root.join('script/storage/rename.py').to_s, source.to_s, destination.to_s,
          out: File::NULL, err: File::NULL)
        status = Timeout.timeout(5) { Process.wait2(pid).last }
      rescue Timeout::Error, SystemCallError
        raise Failure.new(:rename_unavailable)
      ensure
        stop(pid) if pid && !status
      end

      def stop(pid)
        Process.kill('KILL', pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end
end
