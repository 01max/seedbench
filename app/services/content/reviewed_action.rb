module Content
  class ReviewedAction
    Snapshot = Data.define(:input_revision, :cover_hosting_id, :bbcode_id, :nfo_id, :bbcode, :nfo)

    class << self
      def call(operation_id:, attempt_token:)
        context = Covers::WriteContext.call(operation_id: operation_id, attempt_token: attempt_token)
        context.operation.release.with_lock { capture(context) }
      end

      private

      def capture(context)
        release = context.operation.release
        verify_revision!(context)

        inputs = Inputs.new(release)
        raise Covers::Failure.new(:review_required_for_write) unless verified_for_operation?(inputs.hosting, context.operation)

        states = Status.call(release: release).kinds
        raise Covers::Failure.new(:review_required_for_write) unless states.values.all? { |value| value[:state] == 'ready' }

        snapshot(release, inputs, states)
      end

      def verify_revision!(context)
        raise Covers::Failure.new(:selection_changed) unless context.operation.release.input_revision == context.operation.input_revision
      end

      def snapshot(release, inputs, states)
        bbcode, nfo = states.fetch('bbcode').fetch(:revision), states.fetch('nfo').fetch(:revision)
        Snapshot.new(input_revision: release.input_revision, cover_hosting_id: inputs.hosting.id,
          bbcode_id: bbcode.id, nfo_id: nfo.id, bbcode: bbcode.body, nfo: nfo.body)
      end

      def verified_for_operation?(hosting, operation)
        hosting && hosting.verification['workflow_operation_id'] == operation.id && hosting.verification['attempt'] == operation.attempts
      end
    end
  end
end
