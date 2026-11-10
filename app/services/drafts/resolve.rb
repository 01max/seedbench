module Drafts
  class Resolve
    def self.call(release_id:, expected_revision:, snapshot_id:, choice:)
      raise Failure.new(:invalid_choice) unless %w[local remote].include?(choice)
      new(release_id, expected_revision, snapshot_id, choice).call
    end

    def initialize(release_id, revision, snapshot_id, choice)
      @release = Release.find(release_id)
      @revision, @snapshot_id, @choice = revision, snapshot_id, choice
    end

    def call
      link = @release.draft_link
      raise Failure.new(:invalid_link) unless link
      shown = @release.remote_snapshots.find(@snapshot_id)
      observed = Sync.call(link: link)
      @release.with_lock do
        validate!(shown, observed)
        Content.adopt(@release, observed.remote_content) if @choice == 'remote'
        persist(link, observed)
      end
      @release
    end

    private

    def validate!(shown, observed)
      raise Releases::RevisionConflict.new(expected_revision: @revision, actual_revision: @release.input_revision) unless @revision == @release.input_revision
      valid = shown.remote_id == observed.remote_id && shown.remote_content == observed.remote_content && !observed.remote_deleted
      raise Failure.new(:observation_changed) unless valid
      raise Failure.new(:no_conflict) unless @release.draft_state == 'conflicted'
    end

    def persist(link, observed)
      @release.reload.update!(input_revision: @release.input_revision + 1, draft_state: 'synced')
      snapshot = @release.remote_snapshots.create!(provider_connection: link.provider_connection, kind: 'draft', remote_id: link.remote_id,
        local_revision: @release.input_revision, remote_revision: observed.remote_revision, base_content: observed.remote_content,
        remote_content: observed.remote_content, observed_at: Time.current)
      Releases::RecordEvent.call(release_id: @release.id, name: 'draft.resolved', actor: 'operator',
        data: { choice: @choice, shown_snapshot_id: @snapshot_id.to_i, resolved_snapshot_id: snapshot.id })
    end
  end
end
