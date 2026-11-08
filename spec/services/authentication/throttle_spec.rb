require "rails_helper"

RSpec.describe Authentication::Throttle do
  it "enforces a database-backed limit and opens a fresh window" do
    10.times { described_class.check!(ip: "192.0.2.1") }
    expect { described_class.check!(ip: "192.0.2.1") }.to raise_error(described_class::RateLimited)
    LoginThrottle.sole.update!(window_started_at: 16.minutes.ago)

    expect { described_class.check!(ip: "192.0.2.1") }.not_to raise_error
    expect(LoginThrottle.sole.attempts).to eq(1)
  end

  it "removes old windows and retains independent peer buckets" do
    LoginThrottle.create!(client_hash: "old", attempts: 1, window_started_at: 2.days.ago)
    described_class.check!(ip: "192.0.2.1")
    described_class.check!(ip: "192.0.2.2")

    expect(LoginThrottle.count).to eq(2)
    expect(LoginThrottle.pluck(:client_hash)).not_to include("old", "192.0.2.1", "192.0.2.2")
  end
end
