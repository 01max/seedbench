module Content
  class Generate
    Draft = Data.define(:bodies, :dependencies, :expected, :issues)
    Policy = Providers::C411::EbookContent

    def self.call(release:)
      new(Inputs.new(release)).call
    end

    def initialize(inputs)
      @inputs = inputs
      @values = Values.new(inputs).call
    end

    def call
      bodies = { 'bbcode' => Policy.assemble(values: description_values), 'nfo' => nfo }
      dependencies = bodies.keys.index_with { |kind| Dependencies.call(inputs: @inputs, values: @values, kind: kind) }
      issues = Validation.call(bbcode: bodies['bbcode'], nfo: bodies['nfo'], expected: @values, cover_url: @inputs.hosting&.direct_url)
      Draft.new(bodies: bodies, dependencies: dependencies, expected: @values, issues: issues + input_issues)
    end

    private

    def description_values
      @values.transform_values { |value| Policy.escape(value) }.merge('cover' => @inputs.hosting&.direct_url.to_s)
    end

    def nfo
      required = %w[title author format language files size]
      optional = %w[publisher publication_year edition digital_isbn]
      lines = required.map { |field| line(field, @values.fetch(field)) }
      lines += optional.filter_map { |field| line(field, @values[field]) if known?(@values[field]) }
      (lines + technical_lines + [ line('notes', @values.fetch('notes')) ]).join("\n") + "\n"
    end

    def technical_lines
      lines = @inputs.structure.slice('page_count', 'spine_documents').filter_map do |key, value|
        next if value.nil?

        line(key == 'page_count' ? 'pages' : 'documents', value)
      end
      lines << line('print_isbn', @inputs.fact('isbn')) if @inputs.fact('isbn_kind') == 'print' && @inputs.fact('isbn').present?
      lines << line('release_name', @inputs.preparation.release_name) if @inputs.prepared?
      lines
    end

    def line(field, value)
      "#{I18n.t("content.nfo.#{field}")} : #{value.to_s.gsub(/[\r\n]+/, ' ')}"
    end

    def known?(value)
      value.present? && value != I18n.t('content.unknown')
    end

    def input_issues
      errors = []
      errors << { code: 'inspection_required', message: I18n.t('ebooks.inspection_required') } unless @inputs.inspected?
      errors << { code: 'french_required', message: I18n.t('content.errors.french_required') } unless @values['language'].match?(/\b(?:français|fr|fra)\b/i)
      isbn = @inputs.fact('isbn')
      errors << { code: 'invalid_isbn', message: I18n.t('ebooks.review.invalid_isbn') } if isbn.present? && !Ebooks::Isbn.valid?(isbn)
      errors
    end
  end
end
