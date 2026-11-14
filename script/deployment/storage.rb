require 'digest'
require 'json'
require 'tempfile'

# Probes shared storage as the service user before the operator enables publication.
class DeploymentStorage
  ROOT_KEYS = %w[SEEDBENCH_STATE_ROOT SEEDBENCH_SCRATCH_ROOT SEEDBENCH_PAYLOAD_ROOT].freeze

  def initialize(identifier)
    abort 'Run as the configured unprivileged service UID and GID' unless Process.uid.positive? && Process.gid.positive?
    abort 'Expected a 32-character hexadecimal probe identifier' unless identifier&.match?(/\A[0-9a-f]{32}\z/)

    roots = ROOT_KEYS.map { |key| configured_root(key) }
    abort 'State, scratch, and payload roots must be separate' unless separate?(roots)

    @state, @scratch, @payload = roots
    @identifier = identifier
    @canonical = @payload.join(".seedbench-deployment-#{identifier}.bin")
  end

  def prepare
    [ @state, @scratch ].each { |root| Tempfile.create('.seedbench-write-', root) { |file| file.write(@identifier) } }
    staged_payload do |file|
      before = file.stat
      renamed = system('python3', '-I', '/app/script/storage/rename.py', file.path, @canonical.to_s)
      abort 'Canonical rename failed. Check mount permissions, filesystem, and destination' unless renamed
      after = @canonical.stat
      abort 'The canonical file changed device or inode' unless [ before.dev, before.ino ] == [ after.dev, after.ino ]
    end
    read
  end

  def read
    hash = expected_hash
    File.open(@canonical, File::RDONLY | File::NOFOLLOW) do |file|
      abort 'Probe bytes do not match' unless file.stat.file? && Digest::SHA256.file(file).hexdigest == hash
    end
    puts JSON.generate(uid: Process.uid, gid: Process.gid, file: @canonical.basename.to_s, sha256: hash)
  end

  def cleanup
    read
    File.unlink(@canonical)
  end

  private

  def separate?(roots)
    identities = roots.map { |root| [ root.stat.dev, root.stat.ino ] }
    identities.uniq.size == roots.size && roots.permutation(2).none? { |a, b| a.to_s.start_with?("#{b}/") }
  end

  def configured_root(key)
    path = Pathname.new(ENV.fetch(key))
    abort "#{key} must be an existing absolute writable directory without symlinks" unless path.absolute? &&
      path.realpath == path && path.directory? && path.writable? && path.executable?

    path
  end

  def staged_payload
    staging = @payload.join('staging')
    begin
      Dir.mkdir(staging, 0o700)
    rescue Errno::EEXIST
      abort 'Unsafe staging directory' unless staging.directory? && !staging.symlink?
    end

    Tempfile.create('.deployment-probe-', staging) do |file|
      file.write(bytes)
      file.flush
      file.fsync
      File.chmod(0o640, file.path)
      yield file
    end
  end

  def bytes
    "Seedbench storage probe #{@identifier}\n" * 32
  end

  def expected_hash
    Digest::SHA256.hexdigest(bytes)
  end
end

command, identifier = ARGV
abort 'Usage: storage.rb prepare|read|cleanup PROBE_ID' unless %w[prepare read cleanup].include?(command) && ARGV.size == 2
DeploymentStorage.new(identifier).public_send(command)
