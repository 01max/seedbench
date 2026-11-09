require "rails_helper"

RSpec.describe Ebooks::Isbn do
  it "validates checksum independently and equates ISBN-10 with its ISBN-13" do
    expect(described_class.valid?("urn:isbn:0-306-40615-2")).to be(true)
    expect(described_class.canonical("0306406152")).to eq("9780306406157")
    expect(described_class.valid?("9780306406158")).to be(false)
    expect(described_class.valid?("foo9780306406157")).to be(false)
    expect(described_class.valid?("1234567890128")).to be(false)
  end
end
