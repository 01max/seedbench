module Releases
  class Save
    class InvalidChanges < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.values.join(' '))
      end
    end
    LIMITS = { 'proposed_name' => 230, 'title' => 500, 'author' => 500, 'isbn' => 64, 'edition' => 2000, 'language' => 120,
      'publisher' => 500, 'publication_year' => 4, 'isbn_kind' => 20,
      'presentation' => 100_000, 'notes' => 100_000, 'bbcode' => 250_000, 'nfo' => 250_000 }.freeze

    def self.call(release_id:, expected_revision:, changes:, review_facts: true)
      new(release_id, expected_revision, changes, review_facts).call
    end

    def initialize(release_id, expected_revision, changes, review_facts)
      @review_facts = review_facts
      @release = Release.find(release_id)
      @expected_revision = expected_revision
      @changes = validate_changes(changes)
    end

    def call
      @release.with_lock do
        raise RevisionConflict.new(expected_revision: @expected_revision, actual_revision: @release.input_revision) unless @release.input_revision == @expected_revision

        current = EditorValues.call(release: @release)
        @changes = @changes.reject { |field, value| current.fetch(field) == value }
        persist unless @changes.empty?
        @release
      end
    end

    private

    def validate_changes(changes)
      raise InvalidChanges.new(base: I18n.t('workbench.errors.invalid_fields')) unless valid_fields?(changes)

      values = changes.stringify_keys
      errors = values.filter_map do |field, value|
        [ field, I18n.t('workbench.errors.invalid_value', field: I18n.t("workbench.fields.#{field}")) ] unless valid_value?(field, value)
      end.to_h
      errors['title'] = I18n.t('workbench.errors.title_required') if values.key?('title') && values['title'].blank?
      raise InvalidChanges.new(errors) if errors.any?

      values
    end

    def valid_fields?(changes)
      changes.is_a?(Hash) && (changes.keys.map(&:to_s) - LIMITS.keys).empty?
    end

    def valid_value?(field, value)
      value.is_a?(String) && value.valid_encoding? && value.length <= LIMITS.fetch(field) && factual_value?(field, value)
    end

    def factual_value?(field, value)
      return value.blank? || %w[digital print not_applicable unknown].include?(value) if field == 'isbn_kind'
      return value.blank? || value.match?(/\A[1-9]\d{0,3}\z/) if field == 'publication_year'

      true
    end

    def persist
      @payload = @release.payload_revisions.order(number: :desc).first
      raise InvalidChanges.new(edition: I18n.t('workbench.errors.payload_required')) if !@payload && (@changes.keys & EditorValues::FACTS).any?

      Preparation::Invalidate.call(release: @release, changes: @changes)
      @revision = @release.input_revision + 1
      append_facts if @payload && @review_facts
      finish_save
      append_content
      Ebooks::Findings.call(release: @release, payload: @payload) if @payload
    end

    def finish_save
      metadata = @changes.slice(*EditorValues::METADATA)
      search = SearchText.call(title: metadata.fetch('title', @release.title), author: metadata.fetch('author', @release.author))
      @release.update!(metadata.merge('input_revision' => @revision, 'search_text' => search))
      RecordEvent.call(release_id: @release.id, name: 'release.revised', actor: @review_facts ? 'operator' : 'system', data: { fields: @changes.keys.sort })
    end

    def append_facts
      @changes.slice('title', 'author', *EditorValues::FACTS).each do |field, value|
        number = @release.reviewed_facts.where(field: field).maximum(:number).to_i + 1
        @release.reviewed_facts.create!(payload_revision: @payload, field: field, value: value, number: number,
          actor: 'operator', reviewed_at: Time.current)
      end
    end

    def content_dependencies(kind)
      %w[bbcode nfo].include?(kind) ? Content::Capture.call(release: @release, kind: kind) : {}
    end

    def append_content
      @changes.slice(*EditorValues::CONTENT).each do |kind, body|
        number = @release.content_revisions.where(kind: kind).maximum(:number).to_i + 1
        @release.content_revisions.create!(payload_revision: @payload, kind: kind, body: body, number: number,
          input_revision: @revision, origin: 'human', dependencies: content_dependencies(kind))
      end
    end
  end
end
