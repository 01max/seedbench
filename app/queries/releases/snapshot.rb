module Releases
  class Snapshot
    State = Data.define(:payload, :preparation, :contents, :facts, :findings, :covers, :events, :snapshots, :operations, :evidence)

    def self.call(release:)
      State.new(**revisions(release), **observations(release))
    end

    def self.revisions(release)
      { payload: release.payload_revisions.order(number: :desc).first,
        preparation: release.preparation_revisions.order(number: :desc).first,
        contents: latest(release.content_revisions, :kind).index_by(&:kind),
        facts: latest(release.reviewed_facts, :field).index_by(&:field),
        covers: release.cover_revisions.order(number: :desc).limit(10).to_a }
    end
    private_class_method :revisions

    def self.observations(release)
      { findings: current_findings(release).includes(:finding_acknowledgements).to_a,
        events: release.release_events.order(sequence: :desc).limit(50).to_a,
        snapshots: latest(release.remote_snapshots, :kind).index_by(&:kind),
        operations: release.workflow_operations.order(id: :desc).limit(20).to_a,
        evidence: release.evidence_items.order(id: :desc).limit(20).to_a }
    end
    private_class_method :observations

    def self.current_findings(release)
      payload = release.payload_revisions.order(number: :desc).limit(1).select(:id)
      latest(release.findings.where(payload_revision_id: payload), :code).where("json_extract(data, '$.resolved') IS NOT 1")
    end
    private_class_method :current_findings

    def self.latest(relation, group)
      relation.where(id: relation.select("MAX(id)").group(group))
    end
    private_class_method :latest
  end
end
