module Releases
  class Snapshot
    State = Data.define(:payload, :preparation, :contents, :facts, :findings, :covers, :events, :snapshots, :operations, :evidence)

    class << self
      def call(release:)
        State.new(**revisions(release), **observations(release))
      end

      private

      def revisions(release)
        { payload: release.payload_revisions.order(number: :desc).first,
          preparation: release.preparation_revisions.order(number: :desc).first,
          contents: latest(release.content_revisions, :kind).index_by(&:kind),
          facts: latest(release.reviewed_facts, :field).index_by(&:field),
          covers: release.cover_revisions.order(number: :desc).limit(10).to_a }
      end

      def observations(release)
        { findings: current_findings(release).includes(:finding_acknowledgements).to_a,
          events: release.release_events.order(sequence: :desc).limit(50).to_a,
          snapshots: current_snapshots(release),
          operations: release.workflow_operations.order(id: :desc).limit(20).to_a,
          evidence: evidence(release) }
      end

      def current_snapshots(release)
        snapshots = latest(release.remote_snapshots, :kind).index_by(&:kind)
        draft = snapshots['draft']
        if draft && DraftLink.where(provider_connection_id: draft.provider_connection_id, remote_id: draft.remote_id).where.not(release_id: release.id).exists?
          snapshots.delete('draft')
        end
        snapshots
      end

      def evidence(release)
        recent = release.evidence_items.order(id: :desc).limit(20).pluck(:id)
        payload_id = release.payload_revisions.order(number: :desc).pick(:id)
        inspection = release.evidence_items.where(kind: 'inspection', payload_revision_id: payload_id).order(id: :desc).pick(:id)
        release.evidence_items.where(id: recent + [ inspection ]).order(id: :desc).to_a
      end

      def current_findings(release)
        payload = release.payload_revisions.order(number: :desc).limit(1).select(:id)
        latest(release.findings.where(payload_revision_id: payload), :code).where("json_extract(data, '$.resolved') IS NOT 1")
      end

      def latest(relation, group)
        relation.where(id: relation.select('MAX(id)').group(group))
      end
    end
  end
end
