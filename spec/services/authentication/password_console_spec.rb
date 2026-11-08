require "rails_helper"
require "pty"
require "timeout"
require "stringio"

RSpec.describe Authentication::PasswordConsole do
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
    allow(Authentication::ResetPassword).to receive(:call)
    password = "Protected synthetic console password"
    output = run_console([ password, password ])

    expect(output).to include("Toutes les sessions")
    expect(output).not_to include(password)
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
