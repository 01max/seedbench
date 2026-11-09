require 'rails_helper'

RSpec.describe Seedbench::Application do
  it 'provides distinct writable storage roots for synthetic files' do
    roots = Rails.application.config.x.storage.values_at(:state, :scratch, :payload)

    expect(roots.uniq.size).to eq(3)
    roots.each do |root|
      with_synthetic_file(root) do |path|
        expect(path.binread).to eq("Seedbench synthetic fixture\n")
      end
    end
  end

  it 'keeps application and queue state in separate databases' do
    databases = ApplicationRecord.configurations.configs_for(env_name: 'test')

    expect(databases.map(&:name)).to contain_exactly('primary', 'queue')
    expect(databases.map(&:database).uniq.size).to eq(2)
    expect(ApplicationJob.queue_adapter).to be_a(ActiveJob::QueueAdapters::TestAdapter)
  end
end
