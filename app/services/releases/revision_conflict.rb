module Releases
  class RevisionConflict < StandardError
    attr_reader :expected_revision, :actual_revision

    def initialize(expected_revision:, actual_revision:)
      @expected_revision = expected_revision
      @actual_revision = actual_revision
      super("Release inputs changed; reload the current revision before retrying.")
    end
  end
end
