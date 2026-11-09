require 'cgi'

module Content
  class Validation
    Policy = Providers::C411::EbookContent
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

      NFO_LABELS.filter_map { |field| issue('nfo_field', field) unless valid_nfo_field?(field) }
    end

    def valid_nfo_field?(field)
      label = I18n.t("content.nfo.#{field}")
      lines = @nfo.lines.grep(/\A#{Regexp.escape(label)} : /)
      expected = @expected[field]
      return false unless lines.one? && !lines.first.strip.in?([ "#{label} :", "#{label} : #{I18n.t('content.unknown')}" ])

      !expected || lines.first.strip == "#{label} : #{expected}"
    end

    def issue(code, field = nil)
      { code: code, field: field, message: I18n.t("content.errors.#{code}", field: I18n.t("workbench.fields.#{field}", default: field.to_s)) }
    end
  end
end
