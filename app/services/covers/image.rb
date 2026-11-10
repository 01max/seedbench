require 'tempfile'
require 'timeout'

module Covers
  class Image
    class << self
      def call(bytes:)
        raise Failure.new(:too_large) unless bytes.bytesize.between?(1, Fetch::MAX_BYTES)

        scratch = Rails.application.config.x.storage.fetch(:scratch)
        Tempfile.create('cover-source-', scratch) do |source|
          source.binmode.write(bytes)
          source.flush
          Tempfile.create('cover-report-', scratch) { |report| inspect(source, report) }
        end
      end

      private

      def inspect(source, report)
        pid = spawn_probe(source, report)
        status = Timeout.timeout(10) { Process.wait2(pid).last }
        raise Failure.new(:invalid_image) unless status.success? && report.size <= 64.kilobytes

        report.rewind
        JSON.parse(report.read)
      rescue Timeout::Error, JSON::ParserError
        raise Failure.new(:invalid_image), cause: nil
      ensure
        stop(pid) if pid && !status
      end

      def spawn_probe(source, report)
        Process.spawn('python3', '-I', Rails.root.join('script/covers/inspect.py').to_s, source.path,
          out: report, err: File::NULL, rlimit_as: 512.megabytes, rlimit_cpu: 8, rlimit_fsize: 64.kilobytes)
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
