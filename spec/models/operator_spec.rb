require "rails_helper"

RSpec.describe Operator do
  it "uses Devise to authenticate the single operator without an email" do
    create_operator
    operator = described_class.find_for_database_authentication({})

    expect(operator.valid_password?(OperatorHelpers::PASSWORD)).to be(true)
    expect(operator.encrypted_password).not_to include(OperatorHelpers::PASSWORD)
    expect { described_class.create!(id: 2, password: OperatorHelpers::PASSWORD) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "requires at least twelve characters, a matching confirmation, and at most 72 bytes" do
    [ [ "short", "short" ], [ "a" * 73, "a" * 73 ], [ "é" * 40, "é" * 40 ], [ OperatorHelpers::PASSWORD, "different" ] ].each do |password, confirmation|
      operator = described_class.new(id: 1, password: password, password_confirmation: confirmation)
      expect(operator).not_to be_valid
    end
  end
end
