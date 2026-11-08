require "rails_helper"
require "stringio"

RSpec.describe Authentication::ResetPassword do
  let(:replacement) { "A new synthetic operator password" }

  it "initializes the single operator through protected password validation" do
    described_class.call(password: replacement, password_confirmation: replacement)

    expect(Operator.sole.valid_password?(replacement)).to be(true)
    expect(Operator.sole.id).to eq(1)
  end

  it "revokes existing sessions and rejects the previous password" do
    create_operator.lock_access!
    ActiveRecord::SessionStore::Session.create!(session_id: "synthetic-session", data: { "key" => "value" })
    described_class.call(password: replacement, password_confirmation: replacement)

    expect(ActiveRecord::SessionStore::Session.count).to eq(0)
    expect(Operator.sole.valid_password?(OperatorHelpers::PASSWORD)).to be(false)
    expect(Operator.sole.valid_password?(replacement)).to be(true)
    expect(Operator.sole.access_locked?).to be(false)
  end

  it "preserves the password and sessions on invalid input" do
    create_operator
    record = ActiveRecord::SessionStore::Session.create!(session_id: "synthetic-session", data: { "key" => "value" })
    expect { described_class.call(password: "short", password_confirmation: "different") }.to raise_error(described_class::InvalidPassword)
    expect(ActiveRecord::SessionStore::Session.exists?(record.id)).to be(true)
    expect(Operator.sole.valid_password?(OperatorHelpers::PASSWORD)).to be(true)
  end

  it "refuses non-interactive console input" do
    expect { Authentication::PasswordConsole.call(input: StringIO.new(replacement), output: StringIO.new) }
      .to raise_error(Authentication::PasswordConsole::InputError, /terminal interactif/)
    expect(Operator.count).to eq(0)
  end
end
