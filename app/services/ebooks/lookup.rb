module Ebooks
  # Fetches Open Library evidence for the ISBN captured by a queued edition lookup.
  class Lookup
    def self.call(operation:)
      EditionRecord.call(isbn: operation.parameters.fetch('isbn'))
    end
  end
end
