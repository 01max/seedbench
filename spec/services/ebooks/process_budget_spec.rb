require 'rails_helper'

RSpec.describe Ebooks::ProcessBudget do
  let(:directory) { Pathname.new(Dir.mktmpdir('process-budget-')) }

  after { FileUtils.remove_entry(directory) }

  it 'reaps a completed child without waiting for the deadline' do
    pid = Process.spawn('true')
    expect(described_class.call(pid: pid, directory: directory).success?).to be(true)
  end

  it 'bounds wall time for a stalled parser' do
    pid = Process.spawn('sleep', '5')
    expect { described_class.call(pid: pid, directory: directory, seconds: 0.05) }.to raise_error(described_class::Exceeded)
  ensure
    Process.kill('KILL', pid)
    Process.wait(pid)
  end

  it 'rejects excessive scratch output without reading its contents' do
    directory.join('large').open('w') { |file| file.truncate(65.megabytes) }
    expect { described_class.call(pid: Process.pid, directory: directory) }.to raise_error(described_class::Exceeded)
  end

  it 'rejects an excessive number of sidecars' do
    513.times { |index| directory.join(index.to_s).write('') }
    expect { described_class.call(pid: Process.pid, directory: directory) }.to raise_error(described_class::Exceeded)
  end
end
