module Content
  class Workspace
    State = Data.define(:status, :proposals, :bases, :values)

    class << self
      def call(release:)
        accepted = release.content_revisions.where("json_extract(dependencies, '$.proposal_id') IS NOT NULL").select("json_extract(dependencies, '$.proposal_id')")
        proposals = release.content_proposals.where.not(id: accepted).order(id: :desc).limit(5).to_a
        bases = release.content_revisions.where(id: proposals.flat_map { |proposal| proposal.bases.values }).index_by(&:id)
        State.new(status: Status.call(release: release), proposals: proposals, bases: bases, values: Releases::EditorValues.call(release: release))
      end
    end
  end
end
