module Ai
  class Workspace
    State = Data.define(:runs, :catalog, :values, :configured)

    class << self
      def call(release:)
        connection = release.provider_assignments.find_by(role: 'ai')&.provider_connection
        State.new(runs: release.ai_runs.includes(:workflow_operation).order(id: :desc).limit(20).to_a,
          catalog: catalog(release), values: Releases::EditorValues.call(release: release), configured: connection && !connection.configuration_incomplete?)
      end

      private

      def catalog(release)
        EvidenceCatalog.call(release: release)
      rescue Failure
        []
      end
    end
  end
end
