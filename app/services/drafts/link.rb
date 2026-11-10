module Drafts
  class Link
    def self.call(release_id:, payload_release_id:, expected_revision:, payload_revision:, confirmed:, choice:, allowed_operation_id: nil)
      raise Failure.new(:confirmation_required) unless confirmed == true && %w[local remote].include?(choice)
      new(release_id, payload_release_id, expected_revision, payload_revision, choice, allowed_operation_id).call
    end

    def initialize(source, target, source_revision, target_revision, choice, allowed_operation_id)
      @source, @target = Release.find(source), Release.find(target)
      @allowed_operation_id = allowed_operation_id
      @source_revision, @target_revision, @choice = source_revision, target_revision, choice
    end

    def call
      Release.transaction do
        [ @source, @target ].sort_by(&:id).each(&:lock!)
        validate!
        link = @source.draft_link
        snapshot = @source.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last!
        assign(link.provider_connection)
        transfer(link, snapshot)
        @target
      end
    end

    private

    def validate!
      [ [ @source, @source_revision ], [ @target, @target_revision ] ].each do |release, revision|
        raise Releases::RevisionConflict.new(expected_revision: revision, actual_revision: release.input_revision) unless revision == release.input_revision
      end
      validate_target!
      raise Failure.new(:operation_active) if [ @source, @target ].any? { |release| release.workflow_operations.where.not(id: @allowed_operation_id).exists?(state: %w[pending running outcome_unknown]) }
    end

    def validate_target!
      valid = @source.draft_link && !@source.payload_revisions.exists? && @target.payload_revisions.exists? && !@target.draft_link
      raise Failure.new(:invalid_link) unless valid && @target.publication_state == 'unpublished'
    end

    def assign(connection)
      assignment = @target.provider_assignments.find_by!(role: 'publishing')
      raise Failure.new(:different_connection) if assignment.provider_connection_id && assignment.provider_connection_id != connection.id
      assignment.update!(provider_connection: connection, assigned_at: Time.current) unless assignment.provider_connection_id
    end

    def transfer(link, snapshot)
      Content.adopt(@target, Content.local(@source)) if @choice == 'remote'
      @target.reload.update!(input_revision: @target.input_revision + 1, draft_state: @source.draft_state)
      copy_snapshot(snapshot)
      link.update!(release_id: @target.id)
      @source.association(:draft_link).reset
      @source.update!(input_revision: @source.input_revision + 1, draft_state: 'unlinked')
      record_history
    end

    def copy_snapshot(snapshot)
      attributes = snapshot.attributes.except('id', 'created_at', 'updated_at', 'release_id')
      @target.remote_snapshots.create!(attributes.merge(local_revision: @target.input_revision))
    end

    def record_history
      data = { source_release_id: @source.id, payload_release_id: @target.id, choice: @choice }
      [ @source, @target ].each { |release| Releases::RecordEvent.call(release_id: release.id, name: 'draft.linked', actor: 'operator', data: data) }
    end
  end
end
