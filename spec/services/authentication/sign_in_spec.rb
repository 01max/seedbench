require "rails_helper"

RSpec.describe Authentication::SignIn do
  before { create_operator }

  it "persists a digest instead of the session token" do
    result = described_class.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1")

    expect(LoginSession.sole.token_digest).not_to eq(result.token)
    expect(Authentication::Resume.call(token: result.token)).to eq(Operator.sole)
    expect(Operator.sole.password_digest).not_to include(OperatorHelpers::PASSWORD)
  end

  it "rejects invalid passwords without starting a session" do
    expect { described_class.call(password: "wrong", ip: "192.0.2.1") }.to raise_error(described_class::InvalidCredentials)
    expect(LoginSession.count).to eq(0)
  end

  it "expires and revokes sessions" do
    first = described_class.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1")
    LoginSession.sole.update!(expires_at: 1.second.ago)
    expect(Authentication::Resume.call(token: first.token)).to be_nil
    second = described_class.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1")
    Authentication::SignOut.call(token: second.token)
    expect(Authentication::Resume.call(token: second.token)).to be_nil
  end

  it "enforces the database-backed throttle and opens a fresh window" do
    10.times { Authentication::Throttle.check!(ip: "192.0.2.1") }
    expect { described_class.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1") }.to raise_error(Authentication::Throttle::RateLimited)
    LoginThrottle.sole.update!(window_started_at: 16.minutes.ago)
    expect(described_class.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1")).to be_a(described_class::Result)
  end

  it "removes old throttle windows and rejects a second operator" do
    LoginThrottle.create!(client_hash: "old", attempts: 1, window_started_at: 2.days.ago)
    Authentication::Throttle.check!(ip: "192.0.2.1")
    expect(LoginThrottle.count).to eq(1)
    expect { Operator.create!(id: 2, password: OperatorHelpers::PASSWORD) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
