module Ebooks
  class Candidates
    ISBN_PATTERN = /(?<![[:alnum:]])(?:97[89](?:[ -]*\d){10}|\d(?:[ -]*\d){8}[ -]*[\dXx])(?![[:alnum:]])/

    class << self
      def call(report:)
        metadata = Array(report['metadata'])
        text_isbns = Array(report['samples']).flat_map do |sample|
          sample.fetch('text').scan(ISBN_PATTERN).first(10).map do |value|
            { 'field' => 'isbn', 'value' => value, 'source' => sample.fetch('source') }
          end
        end
        (metadata + text_isbns).first(50).uniq.map { |candidate| describe(candidate) }
      end

      private

      def describe(candidate)
        return candidate unless candidate.fetch('field') == 'isbn'

        candidate.merge('checksum_valid' => Isbn.valid?(candidate.fetch('value')),
          'canonical_isbn' => Isbn.canonical(candidate.fetch('value')), 'edition_verified' => false)
      end
    end
  end
end
