module Drafts
  class Guard
    class << self
      def call(write)
        operation = write.workflow_operation.reload
        release = write.release.reload
        validate_operation!(operation, release)
        validate_content!(write, release)
        release
      end

      private

      def validate_content!(write, release)
        raise Failure.new(:connection_changed) unless write.provider_connection.reload.credentials_version == write.request.fetch('connection_version')
        validate_state!(write, release)
        raise Failure.new(:input_changed) unless Content.local(release) == write.request.fetch('content')
      end

      def validate_state!(write, release)
        return if write.action == 'delete'
        raise Failure.new(:conflict_required) if release.draft_state == 'conflicted'
        replacing = write.request['replaces_remote_id'].present?
        raise Failure.new(:remote_missing) if release.draft_state == 'missing' && !replacing
        raise Failure.new(:remote_returned) if replacing && release.draft_state != 'missing'
      end

      def validate_operation!(operation, release)
        live = operation.state == 'running' && operation.lease_expires_at&.future?
        raise Failure.new(:input_changed) unless live && operation.input_revision == release.input_revision
      end
    end
  end
end
