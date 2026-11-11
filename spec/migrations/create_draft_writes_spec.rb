require 'rails_helper'
require Rails.root.join('db/migrate/20261110170000_create_draft_writes')

RSpec.describe CreateDraftWrites do
  self.use_transactional_tests = false
  around { |example| with_committed_cover_database { example.run } }

  it 'rolls back and reapplies with legacy release history and scoped foreign keys intact' do
    release = build_release_graph
    migration = described_class.new
    connection = ApplicationRecord.connection
    migration.suppress_messages { migration.exec_migration(connection, :down) }
    expect(connection.table_exists?(:draft_writes)).to be(false)
    migration.suppress_messages { migration.exec_migration(connection, :up) }
    expect(Release.find(release.id).release_events.sole.name).to eq('release.created')
    expect(connection.select_values('PRAGMA foreign_key_check')).to be_empty
    expect(connection.select_values("SELECT name FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'draft_writes'")).to include('draft_writes_identity', 'draft_writes_body')
  end
end
