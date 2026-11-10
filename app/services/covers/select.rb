module Covers
  class Select
    def self.call(release_id:, expected_revision:, kind:, attributes:, review:)
      new(release_id, expected_revision, kind, attributes.stringify_keys, review.stringify_keys).call
    end

    def initialize(release_id, revision, kind, attributes, review)
      @release, @revision, @kind = Release.find(release_id), revision, kind
      @attributes, @review = attributes, review
    end

    def call
      check_revision!
      @source = Source.call(release: @release, kind: @kind, attributes: @attributes)
      @image = Image.call(bytes: @source.bytes)
      review!
      locator = Asset.store(bytes: @source.bytes, sha256: @image.fetch('sha256'))
      @release.with_lock { persist(locator) }
    rescue ActiveRecord::RecordNotFound, KeyError
      raise Failure.new(:invalid_source), cause: nil
    end

    private

    def check_revision!
      raise Releases::RevisionConflict.new(expected_revision: @revision, actual_revision: @release.input_revision) unless @release.input_revision == @revision
    end

    def review!
      raise Failure.new(:review_required) unless confirmed?('edition_match') && confirmed?('quality_reviewed')
      note = @review['note'].to_s
      raise Failure.new(:review_required) unless note.length <= 2000
      return if @image.fetch('height') >= @image.fetch('width')

      raise Failure.new(:landscape_review) unless confirmed?('comparable_detail') && note.strip.length >= 20
    end

    def persist(locator)
      check_revision!
      cover = append_cover(locator)
      @release.update!(input_revision: @release.input_revision + 1)
      Releases::RecordEvent.call(release_id: @release.id, name: 'cover.selected', actor: 'operator', data: { cover_id: cover.id })
      cover
    end

    def confirmed?(field)
      [ true, '1' ].include?(@review[field])
    end

    def append_cover(locator)
      payload = @release.payload_revisions.order(number: :desc).first
      @release.cover_revisions.create!(number: @release.cover_revisions.maximum(:number).to_i + 1,
        payload_revision: payload, source_kind: %w[url online].include?(@kind) ? 'remote' : @kind, source_locator: locator,
        width: @image.fetch('width'), height: @image.fetch('height'), edition_evidence: provenance)
    end

    def provenance
      @source.provenance.merge(@image.except('width', 'height'), @review.slice('note', 'comparable_detail'))
        .merge('edition_match' => true, 'quality_reviewed' => true,
          'reviewed_facts' => Releases::EditorValues.call(release: @release).slice('title', 'author', 'isbn', 'edition', 'publisher', 'publication_year', 'language'))
    end
  end
end
