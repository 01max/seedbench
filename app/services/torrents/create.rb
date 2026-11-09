require 'tmpdir'
require 'timeout'

module Torrents
  class Create
    INERT_ANNOUNCE = 'https://tracker.invalid/announce'.freeze

    class << self
      def call(payload_path:, output:)
        pid = Process.spawn('mktorrent', '-p', '-l', '20', '-a', INERT_ANNOUNCE, '-o', output.to_s, payload_path.to_s,
          out: File::NULL, err: File::NULL, rlimit_fsize: Bencode::MAX_BYTES, rlimit_cpu: 30)
        status = Timeout.timeout(45) { Process.wait2(pid).last }
        raise Preparation::Failure.new(:torrent_creation) unless status.success?
      rescue Timeout::Error, SystemCallError
        raise Preparation::Failure.new(:torrent_creation)
      ensure
        stop(pid) if pid && !status
      end

      private

      def stop(pid)
        Process.kill('KILL', pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end
end
