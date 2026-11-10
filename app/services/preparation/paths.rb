module Preparation
  class Paths
    def initialize(storage: Rails.application.config.x.storage)
      @storage = storage
    end

    def root(kind = :payload)
      path = Pathname.new(@storage.fetch(kind))
      raise Failure.new(:unsafe_path) unless path.absolute? && path.cleanpath == path

      validate_components(path)
      raise Failure.new(:storage_unavailable) unless accessible?(path)

      path
    rescue SystemCallError
      raise Failure.new(:storage_unavailable)
    end

    def path(locator, kind: :payload, missing: false)
      parts = locator.to_s.split('/', -1)
      raise Failure.new(:unsafe_path) unless valid_parts?(parts)

      base = root(kind)
      path = base.join(*parts)
      validate_components(missing ? path.parent : path)
      raise Failure.new(:unsafe_path) if path.symlink?

      path
    end

    def directory(name, kind: :state)
      path = root(kind).join(name)
      begin
        Dir.mkdir(path, 0o700)
      rescue Errno::EEXIST
        raise Failure.new(:unsafe_path) if path.symlink? || !path.directory?
      end
      path
    end

    def synchronize(payload_id:)
      directory = directory('preparation-locks')
      File.open(directory.join("#{payload_id}.lock"), File::RDWR | File::CREAT | File::NOFOLLOW, 0o600) do |file|
        file.flock(File::LOCK_EX)
        yield
      end
    end

    private

    def accessible?(path)
      path.directory? && path.readable? && path.writable? && path.executable?
    end

    def valid_parts?(parts)
      parts.any? && parts.none? { |part| part.empty? || %w[. ..].include?(part) || part.match?(/[\\\x00-\x1f\x7f]/) }
    end

    def validate_components(path)
      cursor = Pathname.new('/')
      path.each_filename do |part|
        cursor = cursor.join(part)
        raise Failure.new(:unsafe_path) if cursor.lstat.symlink?
      end
    end
  end
end
