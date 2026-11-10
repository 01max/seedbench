module Duplicates
  class Workspace
    State = Data.define(:check, :current, :values, :operation)

    class << self
      def call(release:)
        check = release.duplicate_checks.order(:id).last
        State.new(check: check, current: current?(release, check), values: Releases::EditorValues.call(release: release),
          operation: release.workflow_operations.where(kind: 'duplicate_search').order(:id).last)
      end

      def current?(release, check)
        connection = release.provider_assignments.find_by(role: 'publishing')&.provider_connection
        check && check.query['fingerprint'] == Inputs.fingerprint(Inputs.call(release: release)) &&
          check.query['connection_id'] == connection&.id && check.query['connection_version'] == connection&.credentials_version
      end
    end
  end
end
