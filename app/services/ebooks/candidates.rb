module Ebooks
  class Candidates
    def self.call(report:)
      metadata = Array(report["metadata"])
      text_isbns = Array(report["samples"]).flat_map do |sample|
        sample.fetch("text").scan(/(?:97[89][\d -]{10,18}\d|\b\d[\d -]{7,15}[\dX]\b)/).first(10).map do |value|
          { "field" => "isbn", "value" => value, "source" => sample.fetch("source") }
        end
      end
      (metadata + text_isbns).first(50).uniq.map { |candidate| describe(candidate) }
    end

    def self.describe(candidate)
      return candidate unless candidate.fetch("field") == "isbn"

      candidate.merge("checksum_valid" => Isbn.valid?(candidate.fetch("value")),
        "canonical_isbn" => Isbn.canonical(candidate.fetch("value")), "edition_verified" => false)
    end
    private_class_method :describe
  end
end
