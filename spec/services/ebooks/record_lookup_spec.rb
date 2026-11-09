require "rails_helper"

RSpec.describe Ebooks::RecordLookup do
  let(:release) { build_release_graph }

  it "keeps catalogue candidates local until reviewed and records provenance" do
    stub_request(:get, "https://openlibrary.org/isbn/9780306406157.json").to_return(body: { key: "/books/OL123M", title: "External title", isbn_13: [ "9780306406157" ], physical_format: "ebook" }.to_json)
    operation = Ebooks::RequestLookup.call(release: release, isbn: "9780306406157")
    Workflows::Execute.call(operation_id: operation.id)
    evidence = release.evidence_items.find_by!(kind: "edition_record")
    expect(release.reload.title).to eq("Synthetic book")
    expect(evidence.data).to include("edition_medium" => "digital_record", "digital_edition_verified" => false)
    expect(evidence.data.fetch("candidates")).to include(include("field" => "isbn", "checksum_valid" => true))
    expect(operation.reload.state).to eq("succeeded")
  end
end
