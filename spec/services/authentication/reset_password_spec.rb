require "rails_helper"
require "stringio"

RSpec.describe Authentication::ResetPassword do
  let(:replacement) { "A new synthetic operator password" }

  it "initializes the single operator through protected password validation" do
    described_class.call(password: replacement, password_confirmation: replacement)

    expect(Operator.sole.authenticate(replacement)).to be_truthy
    expect(Operator.sole.id).to eq(1)
  end

  it "revokes existing sessions and rejects the previous password" do
    create_operator
    old = Authentication::SignIn.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1")
    described_class.call(password: replacement, password_confirmation: replacement)

    expect(Authentication::Resume.call(token: old.token)).to be_nil
    expect(Operator.sole.authenticate(OperatorHelpers::PASSWORD)).to be(false)
    expect(Operator.sole.authenticate(replacement)).to be_truthy
    expect(LoginThrottle.count).to eq(0)
  end

  it "preserves the password and sessions on invalid input" do
    create_operator
    login = Authentication::SignIn.call(password: OperatorHelpers::PASSWORD, ip: "192.0.2.1")
    expect { described_class.call(password: "short", password_confirmation: "different") }.to raise_error(described_class::InvalidPassword)
    expect(Authentication::Resume.call(token: login.token)).to eq(Operator.sole)
    expect(Operator.sole.authenticate(OperatorHelpers::PASSWORD)).to be_truthy
  end

  it "refuses non-interactive console input" do
    expect { Authentication::PasswordConsole.call(input: StringIO.new(replacement), output: StringIO.new) }
      .to raise_error(Authentication::PasswordConsole::InputError, /terminal interactif/)
    expect(Operator.count).to eq(0)
  end
end
