require 'rails_helper'
require Rails.root.join('db/migrate/20261110140000_record_ai_request_provenance')

RSpec.describe RecordAiRequestProvenance do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  it 'rolls back and reapplies while retaining legacy runs and scoped foreign keys' do
    release = build_release_graph
    id = release.ai_runs.sole.id
    migration = described_class.new
    connection = ApplicationRecord.connection
    migration.suppress_messages { migration.exec_migration(connection, :down) }
    expect(connection.select_value("SELECT purpose FROM ai_runs WHERE id = #{id}")).to eq('assessment')
    migration.suppress_messages { migration.exec_migration(connection, :up) }
    expect(connection.columns(:ai_runs).map(&:name)).to include('request', 'workflow_operation_id')
    expect(connection.select_value("SELECT json_extract(request, '$.missing') IS NULL FROM ai_runs WHERE id = #{id}")).to eq(1)
    expect(connection.select_values('PRAGMA foreign_key_check')).to be_empty
  end
end
