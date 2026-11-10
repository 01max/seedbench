module Covers
  class Host
    def self.call(operation_id:, attempt_token:)
      raise Failure.new(:transaction_open) if ApplicationRecord.connection.transaction_open?

      new(operation_id, attempt_token).call
    end

    def initialize(operation_id, attempt_token)
      @operation_id, @attempt = operation_id, attempt_token
    end

    def call
      @context = WriteContext.call(operation_id: @operation_id, attempt_token: @attempt)
      bytes = Asset.read(locator: @context.cover.source_locator, sha256: @context.cover.edition_evidence['sha256'])
      source = Image.call(bytes: bytes)
      @url = current_url(bytes, source)
      image = HostedImage.verify(url: @url, source: source, cover: @context.cover)
      persist(image)
    rescue Failure => error
      @upload&.update!(failure_code: error.code) unless @upload&.state == 'outcome_unknown'
      raise
    end

    private

    def current_url(bytes, source)
      previous = @context.cover.cover_hostings.where(provider_connection_id: @context.connection.id).order(:id).last
      return previous.direct_url if previous

      @upload = UploadReceipt.call(context: @context, bytes: bytes, image: source)
      return @upload.direct_url if @upload.direct_url

      url = HostedImage.direct_link(page_url: @upload.page_url)
      @upload.update!(direct_url: url)
      url
    end

    def persist(image)
      @context.operation.release.with_lock do
        fresh = WriteContext.call(operation_id: @operation_id, attempt_token: @attempt)
        raise Failure.new(:selection_changed) unless fresh.cover.id == @context.cover.id && fresh.connection.id == @context.connection.id

        hosting = record(fresh, image)
        @upload&.update!(state: 'verified', failure_code: nil)
        hosting
      end
    end

    def record(context, image)
      hosting = context.cover.cover_hostings.create!(release_id: context.operation.release_id, provider_connection: context.connection,
        direct_url: @url, media_type: image.fetch('media_type'), width: image.fetch('width'), height: image.fetch('height'),
        verification: image.fetch('verification'), verified_at: Time.current)
      Releases::RecordEvent.call(release_id: context.operation.release_id, name: 'cover.hosted', data: { cover_id: context.cover.id, hosting_id: hosting.id })
      hosting
    end
  end
end
