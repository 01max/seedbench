module Ai
  class Workspace
    State = Data.define(:runs, :catalog, :values, :configured, :context, :content_ids)

    class << self
      def call(release:)
        connection = release.provider_assignments.find_by(role: 'ai')&.provider_connection
        bases = content_ids(release)
        State.new(context: Context.call(release: release), content_ids: bases, runs: release.ai_runs.includes(:workflow_operation).order(id: :desc).limit(20).to_a,
          catalog: catalog(release), values: Releases::EditorValues.call(release: release), configured: connection && !connection.configuration_incomplete?)
      end

      private

      def content_ids(release)
        release.content_revisions.where(id: release.content_revisions.select('MAX(id)').group(:kind)).pluck(:kind, :id).to_h
      end

      def catalog(release)
        EvidenceCatalog.call(release: release)
      rescue Failure
        []
      end
    end
  end
end
