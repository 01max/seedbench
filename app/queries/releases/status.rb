module Releases
  class Status
    State = Data.define(:release, :snapshot, :checklist, :active)

    def self.call(release_id:)
      release = Release.find(release_id)
      Preparation::Observe.call(release: release)
      release.with_lock do
        snapshot = Snapshot.call(release: release)
        checklist = Checklist.call(release: release, snapshot: snapshot)
        State.new(release: release, snapshot: snapshot, checklist: checklist,
          active: release.workflow_operations.exists?(state: %w[pending running]))
      end
    end
  end
end
