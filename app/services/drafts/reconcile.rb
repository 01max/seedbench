module Drafts
  class Reconcile
    def self.call(release_id:, write_id:, remote_id: nil, confirmed: false)
      write = Release.find(release_id).draft_writes.find(write_id)
      new(write, remote_id, confirmed).call
    end

    def initialize(write, remote_id, confirmed)
      @write, @remote_id, @confirmed = write, remote_id, confirmed
      @operation = write.workflow_operation
    end

    def call
      validate!
      return interrupt_before_send if @write.state == 'pending' && @write.body.nil?
      id = verified_identity
      recover_imported_link(id)
      link = Receipt.call(write: @write, remote_id: id)
      Sync.call(link: link)
      @operation.update!(state: 'succeeded', phase: 'reconciled', lease_expires_at: nil, finished_at: Time.current)
      @write
    end

    private

    def verified_identity
      id = @write.remote_id || confirmed_id
      data = Providers::C411::Drafts.new(@write.provider_connection).read(id)
      raise Failure.new(:reconcile_mismatch) unless @write.state == 'accepted' || Content.remote(data) == @write.request.fetch('content')
      id
    end

    def interrupt_before_send
      @write.with_lock do
        raise Failure.new(:outcome_unknown) unless @write.body.nil? && @write.state == 'pending'
        @write.update!(state: 'failed', error_code: 'interrupted_before_send')
        @operation.update!(state: 'failed', phase: 'reconciled', lease_expires_at: nil, finished_at: Time.current)
        Releases::RecordEvent.call(release_id: @write.release_id, name: 'draft.reconciled', actor: 'operator', data: { write_id: @write.id, transmitted: false })
      end
      @write
    end

    def recover_imported_link(id)
      existing = DraftLink.find_by(provider_connection_id: @write.provider_connection_id, remote_id: id)
      return unless existing && existing.release_id != @write.release_id
      source, target = existing.release, @write.release.reload
      Link.call(release_id: source.id, payload_release_id: target.id, expected_revision: source.input_revision,
        payload_revision: target.input_revision, confirmed: @confirmed, choice: 'local', allowed_operation_id: @operation.id)
    end

    def validate!
      raise Failure.new(:operation_active) if @operation.state == 'running' && @operation.lease_expires_at&.future?
      valid = %w[sending unknown accepted].include?(@write.state) || (@write.state == 'pending' && @operation.state == 'outcome_unknown')
      raise Failure.new(:outcome_unknown) unless valid
    end

    def confirmed_id
      valid = @confirmed == true && @remote_id.present? && @write.baseline_ids.exclude?(@remote_id.to_s)
      raise Failure.new(:confirmation_required) unless valid
      @remote_id.to_s
    end
  end
end
