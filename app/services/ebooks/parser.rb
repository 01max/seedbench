require "digest"
require "English"
require "timeout"
require "tmpdir"

module Ebooks
  class Parser
    class UnsafePayload < StandardError; end
    MAX_OUTPUT = 256.kilobytes

    def self.call(payload:, ocr: false)
      new(payload, ocr).call
    end

    def initialize(payload, ocr)
      @payload, @ocr = payload, ocr
      @storage = Rails.application.config.x.storage
    end

    def call
      Dir.mktmpdir("inspection-", @storage.fetch(:scratch)) do |directory|
        @directory = Pathname.new(directory)
        File.open(payload_path, File::RDONLY | File::NOFOLLOW) do |source|
          verify!(source)
          report = execute(source)
          verify!(source)
          retain_covers(report)
        end
      end
    rescue UnsafePayload, SystemCallError
      { "error" => "payload_changed" }
    end

    private

    def payload_path
      root = @storage.fetch(:payload).realpath
      locator = Pathname.new(@payload.locator)
      raise UnsafePayload if locator.absolute? || locator.each_filename.include?("..")

      path = root.join(locator)
      raise UnsafePayload unless path.realpath.to_s.start_with?("#{root}/") && !path.symlink?

      path
    end

    def verify!(source)
      source.rewind
      raise UnsafePayload unless source.stat.file? && source.size == @payload.size_bytes && Digest::SHA256.file(source).hexdigest == @payload.sha256

      source.rewind
    end

    def execute(source)
      File.open(@directory.join("report"), "w+") do |output|
        pid = spawn_parser(source, output)
        Timeout.timeout(90) { Process.wait(pid) }
        return { "error" => "parser_failed" } unless $CHILD_STATUS.success?
        return { "error" => "resource_limit" } if output.size > MAX_OUTPUT

        output.rewind
        JSON.parse(output.read)
      rescue Timeout::Error
        { "error" => "resource_limit" }
      ensure
        stop(pid) if pid
      end
    rescue JSON::ParserError
      { "error" => "parser_failed" }
    end

    def spawn_parser(source, output)
      environment = { "PATH" => "/usr/bin:/bin", "HOME" => @directory.to_s, "TMPDIR" => @directory.to_s,
        "LANG" => "C.UTF-8", "QT_QPA_PLATFORM" => "offscreen", "PYTHONNOUSERSITE" => "1" }
      Process.spawn(environment, "python3", Rails.root.join("script/ebooks/inspect.py").to_s,
        "/proc/self/fd/3", @payload.format, @directory.to_s, @ocr.to_s, 3 => source,
        out: output, err: @directory.join("stderr").to_s, chdir: @directory.to_s, unsetenv_others: true,
        pgroup: true, rlimit_as: 1.gigabyte, rlimit_cpu: 60, rlimit_fsize: 32.megabytes, rlimit_nofile: 64)
    end

    def stop(pid)
      Process.kill("KILL", -pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    def retain_covers(report)
      Array(report["covers"]).each do |candidate|
        name = candidate.fetch("sha256")
        raise UnsafePayload unless name.match?(/\A[0-9a-f]{64}\z/)

        data = @directory.join(name).binread
        raise UnsafePayload unless data.bytesize <= 8.megabytes && Digest::SHA256.hexdigest(data) == name

        candidate.delete("file")
        candidate["artifact_locator"] = persist_cover(name, data)
      end
      report
    end

    def persist_cover(name, data)
      directory = @storage.fetch(:state).join("inspection-covers")
      FileUtils.mkdir_p(directory, mode: 0o700)
      raise UnsafePayload if directory.symlink?

      path = directory.join(name)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o600) { |file| file.binmode.write(data) }
      "inspection-covers/#{name}"
    rescue Errno::EEXIST
      raise UnsafePayload unless !path.symlink? && Digest::SHA256.file(path).hexdigest == name

      "inspection-covers/#{name}"
    end
  end
end
