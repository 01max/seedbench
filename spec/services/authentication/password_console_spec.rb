require "rails_helper"
require "pty"
require "timeout"
require "stringio"

RSpec.describe Authentication::PasswordConsole do
  let(:replacement) { "A new synthetic operator password" }

  def protected_input(password, confirmation = password)
    input = instance_double(IO, tty?: true)
    allow(input).to receive(:noecho).and_yield
    allow(input).to receive(:gets).and_return("#{password}\n", "#{confirmation}\n")
    input
  end

  def run_console(input)
    reader, writer = PTY.open
    output = StringIO.new
    interaction = Thread.new { described_class.call(input: writer, output: output) }
    input.each_with_index do |value, index|
      Timeout.timeout(3) { sleep 0.01 until output.string.include?(index.zero? ? "Nouveau" : "Confirmez") }
      expect(writer.echo?).to be(false)
      reader.puts value
    end
    interaction.value
    output.string
  ensure
    reader&.close
    writer&.close
  end

  it "disables terminal echo and never prints the password" do
    allow(described_class).to receive(:save_password)
    password = "Protected synthetic console password"
    output = run_console([ password, password ])

    expect(output).to include("Toutes les sessions")
    expect(output).not_to include(password)
  end

  it "initializes the single operator using Devise password validation" do
    described_class.call(input: protected_input(replacement), output: StringIO.new)

    expect(Operator.sole.valid_password?(replacement)).to be(true)
    expect(Operator.sole.id).to eq(1)
  end

  it "changes the password, invalidates Devise sessions, and unlocks the account" do
    operator = create_operator
    serialized_session = Operator.serialize_into_session(operator)
    operator.update!(failed_attempts: 10, locked_at: Time.current)
    described_class.call(input: protected_input(replacement), output: StringIO.new)

    expect(Operator.sole.valid_password?(OperatorHelpers::PASSWORD)).to be(false)
    expect(Operator.sole.valid_password?(replacement)).to be(true)
    expect(Operator.serialize_from_session(*serialized_session)).to be_nil
    expect(Operator.sole.failed_attempts).to eq(0)
    expect(Operator.sole.locked_at).to be_nil
  end

  [ [ "", "" ], [ "short", "short" ], [ "a" * 73, "a" * 73 ], [ "é" * 40, "é" * 40 ], [ OperatorHelpers::PASSWORD, "different" ] ].each do |password, confirmation|
    it "preserves password, sessions, and account locks when input is invalid (#{password.bytesize} bytes)" do
      operator = create_operator
      serialized_session = Operator.serialize_into_session(operator)
      operator.update!(failed_attempts: 10, locked_at: Time.current)
      input = protected_input(password, confirmation)

      expect { described_class.call(input: input, output: StringIO.new) }.to raise_error(described_class::InputError, /confirmation identique/)
      expect(Operator.sole.valid_password?(OperatorHelpers::PASSWORD)).to be(true)
      expect(Operator.serialize_from_session(*serialized_session)).not_to be_nil
      expect(Operator.sole.access_locked?).to be(true)
      expect(Operator.sole.failed_attempts).to eq(10)
    end
  end

  it "refuses non-interactive input" do
    expect { described_class.call(input: StringIO.new(replacement), output: StringIO.new) }
      .to raise_error(described_class::InputError, /terminal interactif/)
    expect(Operator.count).to eq(0)
  end

  it "keeps interrupted input out of password storage" do
    input = instance_double(IO, tty?: true)
    allow(input).to receive(:noecho).and_raise(Interrupt)
    expect { described_class.call(input: input, output: StringIO.new) }.to raise_error(described_class::InputError, /interrompue/)
  end

  it "rejects a closed input stream" do
    input = instance_double(IO, tty?: true)
    allow(input).to receive(:noecho).and_return(nil)
    expect { described_class.call(input: input, output: StringIO.new) }.to raise_error(described_class::InputError, /interrompue/)
  end
end
