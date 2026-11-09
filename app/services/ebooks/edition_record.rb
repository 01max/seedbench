module Ebooks
  class EditionRecord
    class InvalidIsbn < StandardError; end
    class InvalidRecord < StandardError; end
    ENDPOINT = "https://openlibrary.org".freeze

    def self.call(isbn:)
      raise InvalidIsbn, I18n.t("ebooks.review.invalid_isbn") unless Isbn.valid?(isbn)

      isbn = Isbn.normalize(isbn)
      data = Providers::Http.json(Providers::Http.call(endpoint: ENDPOINT, path: "/isbn/#{isbn}.json"))
      build(data, isbn)
    rescue Providers::Failure => error
      { "lookup_error" => error.code, "queried_isbn" => isbn, "metadata" => [] }
    rescue InvalidRecord
      { "lookup_error" => "invalid_record", "queried_isbn" => isbn, "metadata" => [] }
    end

    def self.build(data, isbn)
      validate_record!(data)

      source = "#{ENDPOINT}#{data.fetch('key')}"
      metadata = [ { "field" => "title", "value" => data.fetch("title").first(500), "source" => source } ]
      metadata += identifiers(data, source)
      format = data["physical_format"].to_s.first(120)
      { "source_url" => source, "queried_isbn" => isbn, "record_format" => format,
        "edition_medium" => medium(format), "digital_edition_verified" => false,
        "publishers" => Array(data["publishers"]).grep(String).first(5).map { |value| value.first(500) },
        "publish_date" => data["publish_date"].to_s.first(120), "metadata" => metadata }
    end
    private_class_method :build

    def self.validate_record!(data)
      raise InvalidRecord unless data.is_a?(Hash) && data["key"].is_a?(String) && data["key"].match?(%r{\A/books/OL\d+M\z}) && data["title"].is_a?(String)
    end
    private_class_method :validate_record!

    def self.identifiers(data, source)
      (Array(data["isbn_10"]) + Array(data["isbn_13"])).grep(String).first(10).map do |value|
        { "field" => "isbn", "value" => value.first(64), "source" => source }
      end
    end
    private_class_method :identifiers

    def self.medium(format)
      return "digital_record" if format.match?(/ebook|e-book|electronic|epub|mobi/i)
      return "print_record" if format.match?(/paperback|hardcover|hardback|broch|reli|print/i)

      "unspecified"
    end
    private_class_method :medium
  end
end
