require 'cgi'

module Content
  class Validation
    Policy = Providers::C411::EbookContent
    NFO_OPTIONAL = %w[publisher publication_year digital_isbn print_isbn edition pages documents release_name].freeze
    NFO_LABELS = %w[title author format language files size].freeze

    def self.call(bbcode:, nfo:, expected: {}, cover_url: nil)
      new(bbcode, nfo, expected, cover_url).call
    end

    def initialize(bbcode, nfo, expected, cover_url)
      @bbcode, @nfo, @expected, @cover_url = bbcode, nfo, expected, cover_url
    end

    def call
      parsed = Bbcode.call(source: @bbcode)
      errors = (parsed.errors + Attributes.errors(parsed.nodes)).map { |code| issue(code) }
      errors += body_errors
      fields = Policy.fields(body: @bbcode)
      errors += fields ? validate_fields(fields) : [ issue('template') ]
      errors + validate_nfo
    end

    private

    def body_errors
      errors = []
      errors << issue('description_size') unless @bbcode.length.between?(20, Policy::MAX_DESCRIPTION)
      errors << issue('unsafe_html') if @bbcode.match?(/<\/?[a-z!][^>]*>/i)
      errors << issue('unverified_escape') if @bbcode.match?(/&#(?:91|93);/)
      errors
    end

    def validate_fields(fields)
      missing = fields.filter_map { |field, value| issue('missing_value', field) if value.blank? || value == I18n.t('content.unknown') }
      missing << issue('cover') unless @cover_url.present? && fields['cover'] == @cover_url && Policy.safe_url?(@cover_url)
      missing + mismatches(fields)
    end

    def mismatches(fields)
      @expected.except('presentation', 'notes').filter_map do |field, value|
        issue('fact_mismatch', field) if fields.key?(field) && CGI.unescapeHTML(fields[field]) != value.to_s
      end
    end

    def validate_nfo
      return [ issue('nfo_size') ] if @nfo.bytesize > 3_000_000

      fields = NFO_LABELS + NFO_OPTIONAL.select { |field| nfo_lines(field).any? || (%w[pages documents].include?(field) && @expected[field].present?) }
      fields.filter_map { |field| issue('nfo_field', field) unless valid_nfo_field?(field) }
    end

    def valid_nfo_field?(field)
      lines = nfo_lines(field)
      expected = @expected[field]
      return false unless expected_available?(field, expected) && nfo_value?(lines)

      !expected || lines.first == expected.to_s.gsub(/[\r\n]+/, ' ').strip
    end

    def expected_available?(field, expected)
      NFO_LABELS.include?(field) || (expected.present? && expected != I18n.t('content.unknown'))
    end

    def nfo_value?(lines)
      lines.one? && lines.first.present? && lines.first != I18n.t('content.unknown')
    end

    def nfo_lines(field)
      labels = [ I18n.t("content.nfo.#{field}") ] + Array(I18n.t("content.nfo_aliases.#{field}", default: []))
      pattern = /\A(?:#{Regexp.union(labels)}) : (.*)\z/
      @nfo.lines.filter_map { |line| pattern.match(line.strip)&.captures&.first&.strip }
    end

    def issue(code, field = nil)
      { code: code, field: field, message: I18n.t("content.errors.#{code}", field: I18n.t("workbench.fields.#{field}", default: field.to_s)) }
    end
  end
end
