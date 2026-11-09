module Content
  class Inputs
    BOOK_FIELDS = %w[title author publisher publication_year language edition isbn isbn_kind].freeze
    attr_reader :release, :payload, :facts, :contents, :cover, :hosting, :preparation, :inspection

    def initialize(release)
      @release = release
      snapshot = Releases::Snapshot.call(release: release)
      @payload, @contents, @cover = snapshot.payload, snapshot.contents, snapshot.covers.first
      @preparation = snapshot.preparation
      @facts = payload ? latest_facts : {}
      @inspection = release.evidence_items.where(payload_revision: payload, kind: 'inspection').order(:id).last if payload
      @hosting = selected_hosting
    end

    def fact(field)
      value = @facts[field]&.value
      value.is_a?(String) ? value : ''
    end

    def prose(kind)
      @contents[kind]&.body.to_s
    end

    def inspected?
      @payload && @inspection && @inspection.data['error'].nil? && @release.inspection_state == 'succeeded'
    end

    def structure
      inspected? ? @inspection.data.fetch('structure', {}) : {}
    end

    def prepared?
      @preparation && @payload && @release.preparation_state == 'prepared' && @preparation.payload_revision_id == @payload.id &&
        @preparation.payload_sha256 == @payload.sha256 && @preparation.payload_size_bytes == @payload.size_bytes
    end

    private

    def latest_facts
      relation = @release.reviewed_facts.where(payload_revision: @payload)
      relation.where(id: relation.select('MAX(id)').group(:field)).index_by(&:field)
    end

    def selected_hosting
      return unless Providers::C411::EbookContent.portrait_cover?(@cover)

      assignment = @release.provider_assignments.find_by(role: 'image_host')
      candidate = @cover.cover_hostings.where(provider_connection_id: assignment&.provider_connection_id).order(:id).last
      candidate if usable_hosting?(candidate)
    end
    def usable_hosting?(candidate)
      Providers::C411::EbookContent.portrait_cover?(candidate) && %w[image/jpeg image/png image/webp].include?(candidate.media_type) &&
        Providers::C411::EbookContent.safe_url?(candidate.direct_url)
    end
  end
end
