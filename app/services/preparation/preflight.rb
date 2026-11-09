require 'tempfile'

module Preparation
  class Preflight
    Result = Data.define(:source, :destination, :identity, :root_identity)

    def self.call(payload:, destination:, paths: Paths.new)
      new(payload, destination, paths).call
    end

    def initialize(payload, destination, paths)
      @payload, @paths = payload, paths
      @source = paths.path(payload.locator)
      @target = paths.path(destination, missing: true)
    end

    def call
      validate_destination!
      identity = Identity.call(path: @source, payload: @payload)
      probe
      Result.new(source: @source, destination: @target, identity: identity, root_identity: @paths.root.stat)
    rescue SystemCallError, IOError
      raise Failure.new(:storage_unavailable)
    end

    private

    def validate_destination!
      raise Failure.new(:unsafe_path) unless @target.parent == @paths.root
      raise Failure.new(:collision) if @source != @target && @target.exist?
      raise Failure.new(:different_filesystem) unless @source.parent.stat.dev == @target.parent.stat.dev
    end

    def probe
      Tempfile.create('.preparation-probe-', @source.parent) do |file|
        target = @target.parent.join(".preparation-probe-#{SecureRandom.uuid}")
        Rename.call(source: Pathname.new(file.path), destination: target)
        File.unlink(target)
      end
    end
  end
end
