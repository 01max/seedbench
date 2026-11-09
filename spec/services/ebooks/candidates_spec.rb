require "rails_helper"

RSpec.describe Ebooks::Candidates do
  def candidates_from(text)
    described_class.call(report: { "samples" => [ { "source" => "pdf:page:2", "text" => text } ] })
  end

  %w[9780306406157 978-0-306-40615-7 0306406152 0-306-40615-2].each do |isbn|
    it "keeps #{isbn} separate from adjacent years and page numbers" do
      candidates = candidates_from("2023 ISBN #{isbn} 2024 p. 42")

      expect(candidates).to include(include("value" => isbn, "checksum_valid" => true, "canonical_isbn" => "9780306406157", "source" => "pdf:page:2"))
    end
  end

  it "retains multiple adjacent ISBNs as distinct source-linked candidates" do
    candidates = candidates_from("ISBN 9780306406157 9780140328721")

    expect(candidates.pluck("value")).to eq(%w[9780306406157 9780140328721])
    expect(candidates.pluck("checksum_valid")).to eq([ true, true ])
  end

  it "accepts spaced digits and lowercase ISBN-10 check characters" do
    candidates = candidates_from("ISBN 978 0 306 40615 7, ISBN 0-8044-2957-x")

    expect(candidates.pluck("canonical_isbn")).to eq(%w[9780306406157 9780804429573])
  end

  it "does not treat a fragment of a longer identifier as an ISBN" do
    expect(candidates_from("file9780306406157ABC 97803064061570 10306406152")).to be_empty
  end

  it "keeps invalid checksums visible without certifying the candidate" do
    expect(candidates_from("ISBN 9780306406158 2024")).to include(include("value" => "9780306406158", "checksum_valid" => false, "edition_verified" => false))
  end
end
