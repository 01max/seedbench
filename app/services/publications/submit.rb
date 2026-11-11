module Publications
  class Submit
    def self.call(operation:)
      new(operation).call
    end

    def initialize(operation)
      @operation = operation
      @release = operation.release
      @attempt = operation.attempt_token
    end

    def call
      @connection = connection
      preparation = Preparation::Validate.call(release: @release)
      torrent = torrent_bytes(preparation)
      cover_and_content = reviewed_content
      category = Providers::C411::DraftCategory.call(connection: @connection, format: preparation.payload_revision.format)
      check = Review.refresh(@operation)
      intent!(preparation, cover_and_content, check)
      receipt = Providers::C411::Publications.new(@connection).submit(fields: fields(preparation, cover_and_content, category),
        torrent: torrent, nfo: cover_and_content.nfo, name: preparation.release_name)
      Receipt.call(operation: @operation, receipt: receipt)
      { 'status' => 'accepted', 'draft_observation' => observe_draft }
    rescue Failure, Preparation::Failure, Providers::Failure, Covers::Failure, Drafts::Failure, Duplicates::Failure, Releases::RevisionConflict => error
      record_failure(error)
    end

    private

    def connection
      assigned = @release.provider_assignments.find_by(role: 'publishing')&.provider_connection
      valid = assigned && assigned.id == @operation.parameters['connection_id'] &&
        assigned.credentials_version == @operation.parameters['connection_version'] && !assigned.configuration_incomplete?
      raise Failure.new(:connection) unless valid

      assigned
    end

    def torrent_bytes(preparation)
      path = Preparation::Paths.new.path(preparation.torrent_locator, kind: :state)
      info = File.open(path, File::RDONLY | File::NOFOLLOW) do |file|
        Torrents::Bencode.decode(file.read(Torrents::Bencode::MAX_BYTES + 1)).fetch('info')
      end
      raise Preparation::Failure.new(:invalid_torrent) unless Digest::SHA1.hexdigest(Torrents::Bencode.encode(info)) == preparation.torrent_info_hash

      Torrents::Bencode.encode({ 'info' => info })
    rescue Torrents::Bencode::Invalid, KeyError, TypeError, SystemCallError, IOError
      raise Preparation::Failure.new(:invalid_torrent), cause: nil
    end

    def reviewed_content
      Covers::Host.call(operation_id: @operation.id, attempt_token: @attempt)
      Content::ReviewedAction.call(operation_id: @operation.id, attempt_token: @attempt)
    end

    def intent!(preparation, content, check)
      @release.with_lock do
        verify_attempt!(preparation, content, check)
        Workflows::RecordOutcome.call(operation_id: @operation.id, attempt_token: @attempt,
          phase: 'publication_sending', reference: { prepared_info_hash: preparation.torrent_info_hash, duplicate_check_id: check.id })
        @release.update!(publication_state: 'submitting')
      end
    end

    def verify_attempt!(preparation, content, check)
      raise Failure.new(:input_changed) unless live_attempt?(preparation)

      connection
      reasons = Gate.call(release: @release, before_send: true)
      raise Failure.new(reasons) if reasons.any?

      Review.verify!(release: @release, refreshed_check: check)
      raise Failure.new(:input_changed) unless current_content?(content)
    end

    def live_attempt?(preparation)
      @operation.reload
      @operation.state == 'running' && @operation.attempt_token == @attempt && @operation.lease_expires_at&.future? &&
        @operation.input_revision == @release.input_revision && @operation.parameters['preparation_id'] == preparation.id
    end

    def current_content?(content)
      latest = Content::Inputs.new(@release)
      [ content.bbcode_id, content.nfo_id, content.cover_hosting_id ] ==
        [ latest.contents['bbcode']&.id, latest.contents['nfo']&.id, latest.hosting&.id ]
    end

    def fields(preparation, content, category)
      category.merge('options' => JSON.generate(category.fetch('options')), 'title' => preparation.release_name,
        'description' => content.bbcode, 'descriptionFormat' => 'standard')
    end

    def observe_draft
      return 'unlinked' unless @release.reload.draft_link

      Drafts::AfterPublication.call(release_id: @release.id) ? 'present' : 'missing'
    rescue Providers::Failure, Drafts::Failure
      'unavailable'
    end

    def record_failure(error)
      codes = error.respond_to?(:codes) ? error.codes : [ error.respond_to?(:code) ? error.code : 'input_changed' ]
      @release.with_lock do
        if @release.publication_state == 'submitting'
          rejected = error.is_a?(Providers::Failure) && error.code.match?(/\Ahttp_4(?!08)\d\d\z/)
          @release.update!(publication_state: rejected ? 'failed' : 'outcome_unknown')
        end
      end
      { 'status' => @release.publication_state == 'outcome_unknown' ? 'unknown' : 'failed', 'errors' => codes }
    end
  end
end
