require "rails_helper"

RSpec.describe Releases::Queue do
  it "paginates more than twenty records and keeps a deep selection visible" do
    85.times { |index| Release.create!(title: "Book #{index}", author: "Synthetic") }
    selected = Release.order(:id).offset(80).first
    page = described_class.call(release_id: selected.id)

    expect(page.total).to eq(85)
    expect(page.page).to eq(3)
    expect(page.position).to eq(81)
    expect(page.records.map(&:id)).to include(selected.id)
    expect(page.previous_id).to eq(Release.order(:id).offset(79).pick(:id))
  end

  it "searches title and author with literal wildcard characters" do
    book = Release.create!(title: "A 100% book", author: "Test writer")
    Release.create!(title: "A different book", author: "Other")

    expect(described_class.call(q: "writer").records).to eq([ book ])
    expect(described_class.call(q: "%").records).to eq([ book ])
    expect(described_class.call(q: "no match").selected).to be_nil
  end

  it "filters measured states without claiming readiness" do
    book = Release.create!(title: "Prepared", inspection_state: "succeeded", preparation_state: "prepared")
    published = Release.create!(title: "Published", publication_state: "published")

    expect(described_class.call(state: "prepared").records).to eq([ book ])
    expect(described_class.call(state: "published").records).to eq([ published ])
    expect(described_class.call(state: "inspection").records).to eq([ published ])
    expect(described_class.call(state: "review").records).to eq([ book ])
  end

  it "keeps an explicitly selected book identifiable outside a changed filter" do
    book = Release.create!(title: "Not matching")
    page = described_class.call(q: "something else", release_id: book.id, page: 500)

    expect(page.selected).to eq(book)
    expect(page.position).to be_nil
    expect(page.page).to eq(1)
  end

  it "shows duplicate decisions from actual records and clamps malformed criteria" do
    release = build_release_graph
    release.duplicate_decisions.create!(duplicate_check: release.duplicate_checks.sole,
      candidate_key: "confirmed-second", decision: "confirmed", actor: "operator", reviewed_at: Time.current)

    expect(described_class.call(state: "duplicate").records).to eq([ release ])
    expect(described_class.call(state: "forged", page: -4).criteria[:state]).to eq("all")
  end
end
