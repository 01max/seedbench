module Preparation
  class Record
    def self.call(operation:, result:)
      new(operation, result).call
    end

    def initialize(operation, result)
      @operation, @result = operation, result
      @release = operation.release
    end

    def call
      if @result['error_code']
        @release.update!(preparation_state: 'failed')
        return { failed: true, error_code: @result.fetch('error_code') }
      end

      preparation = append_preparation
      PayloadMove.find_by!(workflow_operation_id: @operation.id).update!(state: 'completed')
      @release.update!(preparation_state: 'prepared', input_revision: @release.input_revision + 1)
      Releases::RecordEvent.call(release_id: @release.id, name: 'preparation.verified', data: { preparation_id: preparation.id, operation_id: @operation.id })
      { preparation_id: preparation.id }
    end

    private

    def append_preparation
      payload = @release.payload_revisions.find(@operation.parameters.fetch('payload_revision_id'))
      @release.preparation_revisions.create!(payload_revision: payload, number: @release.preparation_revisions.maximum(:number).to_i + 1,
        release_name: @operation.parameters.fetch('release_name'), payload_name: @result.fetch('payload_name'),
        torrent_locator: @result.fetch('torrent_locator'), torrent_info_hash: @result.fetch('torrent_info_hash'),
        payload_sha256: payload.sha256, payload_size_bytes: payload.size_bytes, policy_version: Current::POLICY, prepared_at: Time.current)
    end
  end
end
