module Ebooks
  class Lookup
    def self.call(operation:)
      EditionRecord.call(isbn: operation.parameters.fetch('isbn'))
    end
  end
end
