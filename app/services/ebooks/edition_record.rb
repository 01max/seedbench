module Ebooks
  class EditionRecord
    class InvalidIsbn < StandardError; end
    class InvalidRecord < StandardError; end
    ENDPOINT = "https://openlibrary.org".freeze

    class << self
      def call(isbn:)
        raise InvalidIsbn, I18n.t("ebooks.review.invalid_isbn") unless Isbn.valid?(isbn)

        isbn = Isbn.normalize(isbn)
        data = Providers::Http.json(Providers::Http.call(endpoint: ENDPOINT, path: "/isbn/#{isbn}.json", redirects: 2))
        build(data, isbn)
      rescue Providers::Failure => error
        { "lookup_error" => error.code, "queried_isbn" => isbn, "metadata" => [] }
      rescue InvalidRecord
        { "lookup_error" => "invalid_record", "queried_isbn" => isbn, "metadata" => [] }
      end

      private

      def build(data, isbn)
        validate_record!(data)

        source = "#{ENDPOINT}#{data.fetch('key')}"
        format = data["physical_format"].to_s.first(120)
        { "source_url" => source, "queried_isbn" => isbn, "record_format" => format,
          "edition_medium" => medium(format), "digital_edition_verified" => false,
          "isbn_matches_query" => isbn_match?(data, source, isbn),
          "publishers" => Array(data["publishers"]).grep(String).first(5).map { |value| value.first(500) },
          "publish_date" => data["publish_date"].to_s.first(120), "metadata" => metadata(data, source) }
      end

      def metadata(data, source)
        candidates = [ { "field" => "title", "value" => data.fetch("title").first(500), "source" => source } ]
        candidates += identifiers(data, source)
        edition = edition_description(data)
        candidates << { "field" => "edition", "value" => edition, "source" => source } if edition.present?
        candidates
      end

      def edition_description(data)
        (Array(data["publishers"]) + [ data["publish_date"], data["physical_format"] ]).grep(String).first(7).map(&:strip).reject(&:empty?).join(" · ").first(2000)
      end

      def isbn_match?(data, source, isbn)
        identifiers(data, source).any? { |candidate| Isbn.canonical(candidate["value"]) == Isbn.canonical(isbn) }
      end

      def validate_record!(data)
        raise InvalidRecord unless data.is_a?(Hash) && data["key"].is_a?(String) && data["key"].match?(%r{\A/books/OL\d+M\z}) && data["title"].is_a?(String)
      end

      def identifiers(data, source)
        (Array(data["isbn_10"]) + Array(data["isbn_13"])).grep(String).first(10).map do |value|
          { "field" => "isbn", "value" => value.first(64), "source" => source }
        end
      end

      def medium(format)
        return "digital_record" if format.match?(/ebook|e-book|electronic|epub|mobi/i)
        return "print_record" if format.match?(/paperback|hardcover|hardback|broch|reli|print/i)

        "unspecified"
      end
    end
  end
end
