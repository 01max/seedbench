module Releases
  class Transition
    class NotAllowed < StandardError
      attr_reader :dimension, :from, :to

      def initialize(dimension:, from:, to:)
        @dimension, @from, @to = dimension, from, to
        super("The requested workflow state transition is not allowed.")
      end
    end

    def self.call(release_id:, dimension:, to:, expected_revision:)
      raise NotAllowed.new(dimension: dimension, from: nil, to: to) unless WorkflowTransitions::NEXT_STATES.key?(dimension)

      release = Release.find(release_id)
      release.with_lock do
        raise RevisionConflict.new(expected_revision: expected_revision, actual_revision: release.input_revision) unless release.input_revision == expected_revision
        from = release.public_send("#{dimension}_state")
        return release if from == to
        raise NotAllowed.new(dimension: dimension, from: from, to: to) unless WorkflowTransitions.allowed?(dimension: dimension, from: from, to: to)

        release.update!("#{dimension}_state" => to)
        RecordEvent.call(release_id: release.id, name: "#{dimension}.transitioned", data: { from: from, to: to })
        release
      end
    end
  end
end
