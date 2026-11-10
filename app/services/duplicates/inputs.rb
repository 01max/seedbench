require 'digest'

module Duplicates
  class Inputs
    class << self
      def call(release:)
        values = Releases::EditorValues.call(release: release).slice('title', 'author', 'isbn', 'edition', 'publisher', 'publication_year', 'language')
        payload = release.payload_revisions.order(number: :desc).first
        values.merge('format' => payload&.format.to_s, 'payload_revision_id' => payload&.id)
      end

      def fingerprint(inputs)
        Digest::SHA256.hexdigest(JSON.generate(inputs.sort.to_h))
      end

      def queries(inputs)
        title = inputs.fetch('title').strip
        author = inputs.fetch('author').strip
        variants = [ title, title.tr('’', "'").gsub(/[^\p{Alnum}\s]/, ' ').squish, "#{title} #{author}".strip ]
        variants << Ebooks::Isbn.normalize(inputs['isbn']) if Ebooks::Isbn.valid?(inputs['isbn'])
        variants.map { |value| value.first(500) }.reject(&:empty?).uniq
      end
    end
  end
end
