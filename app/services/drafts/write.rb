module Drafts
  class Write
    def self.call(operation:)
      new(operation).call
    end

    def initialize(operation)
      @operation = operation
      @write = operation.draft_write
      @client = Providers::C411::Drafts.new(@write.provider_connection)
    end

    def call
      raise Failure.new(:transaction_open) if ApplicationRecord.connection.transaction_open?
      return summary if @write.state == 'accepted'
      raise Failure.new(:outcome_unknown) unless @write.state == 'pending'
      send_draft
      summary
    rescue Providers::Failure, Failure, Covers::Failure, Preparation::Failure, ::Content::Confirm::InvalidContent => error
      record_error(error)
    end

    private

    def send_draft
      PrepareWrite.call(write: @write)
      body = Providers::C411::DraftBody.call(write: @write)
      baseline = baseline_ids
      intent(body, baseline)
      id = @write.action == 'create' ? @client.create(body) : update(body)
      link = Receipt.call(write: @write, remote_id: id)
      Sync.call(link: link)
    end

    def baseline_ids
      return [] unless @write.action == 'create'
      listing = @client.list
      full = listing.count.is_a?(Integer) && listing.maximum.is_a?(Integer) && listing.count >= listing.maximum
      raise Failure.new(:slots_full) if full
      listing.ids
    end

    def intent(body, baseline)
      @write.release.with_lock do
        Guard.call(@write)
        @write.update!(body: body, baseline_ids: baseline, state: 'sending')
        @operation.update!(phase: 'draft_sending')
      end
    end

    def update(body)
      @client.update(@write.remote_id, body)
      @write.remote_id
    end

    def summary
      { 'write_id' => @write.id, 'status' => @write.state, 'error_code' => @write.error_code }
    end

    def record_error(error)
      if @write.reload.state == 'accepted'
        @write.update!(error_code: 'readback_failed')
      else
        uncertain = @write.state == 'sending' && !error.code.to_s.match?(/\Ahttp_4(?!08)\d\d\z/)
        @write.update!(state: uncertain ? 'unknown' : 'failed', error_code: error.code)
      end
      summary
    end
  end
end
