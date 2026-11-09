module Content
  class Values
    attr_reader :inputs

    def initialize(inputs)
      @inputs = inputs
    end

    def call
      values = Inputs::BOOK_FIELDS.index_with { |field| reviewed(field) }
      values.merge('language' => language, 'digital_isbn' => digital_isbn, 'cover' => @inputs.hosting&.direct_url.to_s,
        'presentation' => @inputs.prose('presentation'), 'notes' => @inputs.prose('notes').presence || I18n.t('content.no_notes'),
        'format' => format_name, 'files' => @inputs.inspected? ? "1 #{format_name}" : unknown,
        'size' => @inputs.inspected? ? size : unknown)
    end

    private

    def unknown
      I18n.t('content.unknown')
    end

    def reviewed(field)
      value = @inputs.fact(field)
      return unknown if %w[title author].include?(field) && value != @inputs.release.public_send(field).to_s

      value.presence || unknown
    end

    def language
      value = @inputs.fact('language')
      %w[fr fra français].include?(value.downcase) ? I18n.t('content.french') : value.presence || unknown
    end

    def digital_isbn
      kind, isbn = @inputs.fact('isbn_kind'), @inputs.fact('isbn')
      return I18n.t('content.not_applicable') if %w[print not_applicable].include?(kind)
      return Ebooks::Isbn.normalize(isbn) if kind == 'digital' && Ebooks::Isbn.valid?(isbn)

      unknown
    end

    def format_name
      @inputs.inspected? ? @inputs.payload.format.upcase : unknown
    end

    def size
      bytes = @inputs.payload.size_bytes
      unit, divisor = [ [ 'To', 10**12 ], [ 'Go', 10**9 ], [ 'Mo', 10**6 ] ].find { |_, threshold| bytes >= threshold } || [ 'Mo', 10**6 ]
      readable = ActiveSupport::NumberHelper.number_to_rounded(bytes.to_f / divisor, precision: 2, locale: :fr)
      I18n.t('content.bytes', count: bytes, value: readable, unit: unit)
    end
  end
end
