require "rails_helper"

RSpec.describe Ebooks::EditionRecord do
  let(:isbn) { "9780306406157" }
  let(:record) { { key: "/books/OL123M", title: "Catalog title", isbn_13: [ isbn ], physical_format: "Paperback", publishers: [ "Test publisher" ] } }

  it "keeps a print edition candidate distinct from digital verification" do
    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json").to_return(body: record.to_json)
    result = described_class.call(isbn: isbn)
    expect(result).to include("edition_medium" => "print_record", "digital_edition_verified" => false)
    expect(result.fetch("metadata")).to include(include("field" => "title", "source" => "https://openlibrary.org/books/OL123M"))
  end

  it "retains a truthful unavailable result" do
    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json").to_timeout
    expect(described_class.call(isbn: isbn)).to include("lookup_error" => "network_error", "metadata" => [])
  end

  it "rejects invalid ISBNs before a request" do
    expect { described_class.call(isbn: "9780306406158") }.to raise_error(described_class::InvalidIsbn)
  end

  it "rejects malformed or unrelated record identities" do
    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json").to_return(body: { key: "https://untrusted.invalid", title: "Bad" }.to_json)
    expect(described_class.call(isbn: isbn)).to include("lookup_error" => "invalid_record")
  end
end
