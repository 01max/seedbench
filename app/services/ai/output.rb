module Ai
  class Output
    MARKUP = %r{https?://|<[/!a-z]|\[/?[a-z]}i
    TECHNICAL = /\b(?:ISBN|EPUB|MOBI|PDF|NFO|BBCode)\b|\d\s*(?:pages?|octets?|[MG]io?|[MG]B)\b/i

    def self.call(purpose:, output:, pack:)
      new(purpose, output, pack).call
    end

    def initialize(purpose, output, pack)
      @purpose, @output = purpose, output
      @evidence = pack.fetch('items').index_by { |item| item.fetch('id') }
    end

    def call
      schema = Schemas.call(purpose: @purpose, evidence_ids: @evidence.keys)
      raise Failure.new(:invalid_output) unless SchemaValidation.call(value: @output, schema: schema)
      raise Failure.new(:invalid_output) unless plain?(@output.fetch('limitations'), 1200)

      @purpose == 'assessment' ? assessment! : prose!
      @output
    end

    private

    def plain?(text, limit, empty: true)
      text.is_a?(String) && text.valid_encoding? && text.length <= limit && (empty || text.present?) && !text.match?(MARKUP)
    end

    def citations?(ids, required: true)
      ids.uniq.size == ids.size && ids.size <= 8 && (!required || ids.any?) && (ids - @evidence.keys).empty?
    end

    def assessment!
      candidates, findings = @output.values_at('candidates', 'findings')
      valid = candidates.size <= 12 && findings.size <= 8 && candidates.all? { |item| candidate?(item) }
      valid &&= findings.all? { |item| finding?(item) }
      raise Failure.new(:invalid_output) unless valid
    end

    def finding?(item)
      plain?(item['summary'], 1200, empty: false) && citations?(item['evidence_ids'])
    end

    def candidate?(item)
      value, ids = item.values_at('value', 'evidence_ids')
      limit = Releases::Save::LIMITS.fetch(item.fetch('field'))
      return false unless plain?(value, limit, empty: false) && citations?(ids)

      ids.any? { |id| normalized(@evidence.fetch(id).fetch('text')).include?(normalized(value)) }
    end

    def normalized(text)
      text.unicode_normalize(:nfkc).downcase.gsub(/[[:space:]]+/, ' ').strip
    end

    def prose_field?(kind, value)
      return true if value.nil?

      plain?(value, kind == 'presentation' ? 4000 : 2000, empty: false) && !value.match?(TECHNICAL)
    end

    def prose!
      values = @output.slice('presentation', 'notes')
      valid = values.all? do |kind, value|
        prose_field?(kind, value)
      end
      valid &&= citations?(@output.fetch('evidence_ids'), required: values.values.any?(&:present?))
      raise Failure.new(:invalid_output) unless valid
    end
  end
end
