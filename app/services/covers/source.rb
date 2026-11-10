module Covers
  class Source
    Result = Data.define(:bytes, :provenance)

    def self.call(release:, kind:, attributes:)
      new(release, attributes).call(kind)
    end

    def initialize(release, attributes)
      @release, @attributes = release, attributes
    end

    def call(kind)
      case kind
      when 'embedded' then embedded
      when 'online' then online
      when 'manual' then manual
      when 'url'
        result = Fetch.call(url: @attributes.fetch('image_url', ''))
        Result.new(bytes: result.bytes, provenance: { 'source_url' => result.url })
      else raise Failure.new(:invalid_source)
      end
    end

    private

    def embedded
      evidence = current_evidence(@attributes['evidence_id'])
      sha256 = @attributes['candidate_id'].to_s
      path, = Ebooks::CoverAsset.call(release: @release, evidence_id: evidence.id, sha256: sha256)
      Result.new(bytes: Asset.read(locator: "inspection-covers/#{sha256}", sha256: sha256),
        provenance: { 'evidence_id' => evidence.id, 'extracted_locator' => path.basename.to_s })
    end

    def online
      evidence = current_evidence(@attributes['evidence_id'])
      id = Integer(@attributes['candidate_id'], exception: false)
      raise Failure.new(:invalid_source) unless id && Array(evidence.data['cover_ids']).include?(id)

      url = "https://covers.openlibrary.org/b/id/#{id}-L.jpg?default=false"
      result = Fetch.call(url: url)
      Result.new(bytes: result.bytes, provenance: { 'evidence_id' => evidence.id, 'source_url' => result.url,
        'edition_record' => evidence.data.slice('source_url', 'queried_isbn', 'edition_medium', 'publishers', 'publish_date', 'isbn_matches_query') })
    end

    def current_evidence(id)
      evidence = @release.evidence_items.find(id)
      current = @release.payload_revisions.order(number: :desc).pick(:id)
      raise Failure.new(:invalid_source) unless evidence.payload_revision_id == current

      evidence
    end

    def manual
      upload = @attributes['image']
      raise Failure.new(:invalid_source) unless upload.respond_to?(:read) && upload.respond_to?(:original_filename)

      upload.rewind
      bytes = upload.read(Fetch::MAX_BYTES + 1)
      name = File.basename(upload.original_filename.to_s.tr('\\', '/')).first(200)
      Result.new(bytes: bytes, provenance: { 'original_filename' => name })
    end
  end
end
