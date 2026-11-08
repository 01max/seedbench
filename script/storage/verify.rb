require "digest"
require "json"

class StorageProbe
  def initialize
    configured = ENV.fetch("SEEDBENCH_PAYLOAD_ROOT")
    raise "Payload root must be an absolute container path" unless Pathname.new(configured).absolute?

    @root = File.realpath(configured)
    @id = ENV.fetch("PROBE_ID")
    raise "Invalid probe identifier" unless @id.match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
    raise "Run the probe as an unprivileged user" if Process.uid.zero?

    @staging_base = File.realpath(ENV.fetch("STAGING_ROOT", @root))
  end

  def prepare
    raise "Probe destination already exists" if occupied?(destination) || occupied?(staging)

    Dir.mkdir(destination, 0750)
    Dir.mkdir(staging, 0700)
    verify_same_filesystem!
    write_source
    before = File.stat(source)
    File.rename(source, payload)
    after = File.stat(payload)
    raise "Rename changed file identity" unless [ before.dev, before.ino ] == [ after.dev, after.ino ]
    raise "Staged source still exists" if occupied?(source)

    report.merge(single_inode_rename: true, staged_source_absent: true)
  end

  def read
    result = report
    begin
      File.write(File.join(destination, "write-check"), "unexpected write")
    rescue Errno::EROFS, Errno::EACCES => error
      return result.merge(write_rejected: error.class.name)
    end
    raise "Client view unexpectedly allowed a write"
  end

  def cleanup
    report
    raise "Unexpected staging entries" unless Dir.children(staging).empty?

    File.unlink(payload)
    Dir.rmdir(destination)
    Dir.rmdir(staging)
    { cleaned: true, probe_id: @id }
  end

  private

  def bytes
    "Seedbench synthetic mount verification: #{@id}\n" * 4096
  end

  def destination
    File.join(@root, ".seedbench-storage-#{@id}")
  end

  def staging
    File.join(@staging_base, ".seedbench-staging-#{@id}")
  end

  def source
    File.join(staging, "probe.bin")
  end

  def payload
    File.join(destination, "probe.bin")
  end

  def occupied?(path)
    File.exist?(path) || File.symlink?(path)
  end

  def verify_same_filesystem!
    return if File.stat(staging).dev == File.stat(destination).dev

    Dir.rmdir(staging)
    Dir.rmdir(destination)
    raise "Staging and payload must be on the same filesystem"
  end

  def write_source
    File.open(source, File::WRONLY | File::CREAT | File::EXCL, 0640) do |file|
      file.write(bytes)
      file.fsync
    end
  end

  def report
    raise "Symlink in probe payload path" if File.symlink?(destination) || File.symlink?(payload)
    raise "Payload size mismatch" unless File.size(payload) == bytes.bytesize

    hash = Digest::SHA256.file(payload).hexdigest
    raise "Payload hash mismatch" unless hash == Digest::SHA256.hexdigest(bytes)

    { container_root: @root, relative_path: File.join(File.basename(destination), "probe.bin"),
      bytes: bytes.bytesize, sha256: hash, uid: Process.uid, gid: Process.gid }
  end
end

begin
  command = ARGV.fetch(0)
  raise "Use prepare, read, or cleanup" unless %w[prepare read cleanup].include?(command)

  puts JSON.generate(StorageProbe.new.public_send(command))
rescue StandardError => error
  warn JSON.generate(error: error.class.name, message: error.message)
  exit 1
end
