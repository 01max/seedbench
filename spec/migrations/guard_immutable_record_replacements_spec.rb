require "rails_helper"
require "tmpdir"
require Rails.root.join("db/migrate/20261108160000_guard_immutable_record_replacements")

RSpec.describe GuardImmutableRecordReplacements do
  before { stub_const("#{described_class}::TABLES", %w[release_events]) }

  def with_legacy_database
    Dir.mktmpdir("seedbench-legacy-history-") do |directory|
      path = File.join(directory, "legacy.sqlite3")
      connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(adapter: "sqlite3", database: path)
      create_legacy_events(connection)
      migration = described_class.new
      allow(migration).to receive(:connection).and_return(connection)
      yield connection, migration, path
    ensure
      connection&.disconnect!
    end
  end

  def create_legacy_events(connection)
    connection.create_table(:release_events) do |table|
      table.integer :release_id, null: false
      table.integer :sequence, null: false
      table.string :name, null: false
    end
    connection.add_index(:release_events, [ :release_id, :sequence ], unique: true)
    %w[UPDATE DELETE].each do |action|
      connection.execute("CREATE TRIGGER legacy_no_#{action.downcase} BEFORE #{action} ON release_events BEGIN SELECT RAISE(ABORT, 'History is append-only'); END")
    end
    connection.execute("INSERT INTO release_events (id, release_id, sequence, name) VALUES (1, 1, 1, 'original')")
  end

  it "protects existing rows when upgrading a database with legacy guards" do
    with_legacy_database do |connection, migration|
      migration.suppress_messages { migration.up }

      expect { connection.execute("INSERT OR REPLACE INTO release_events VALUES (1, 1, 1, 'rewritten')") }
        .to raise_error(ActiveRecord::RecordNotUnique)
      expect { connection.execute("INSERT OR REPLACE INTO release_events VALUES (2, 1, 1, 'rewritten')") }
        .to raise_error(ActiveRecord::RecordNotUnique)
      expect(connection.select_value("SELECT name FROM release_events WHERE id = 1")).to eq("original")
    end
  end

  it "protects an independent SQLite connection with recursive triggers disabled" do
    with_legacy_database do |connection, migration, path|
      migration.suppress_messages { migration.up }
      database = SQLite3::Database.new(path)
      database.execute("PRAGMA recursive_triggers = OFF")

      expect(database.get_first_value("PRAGMA recursive_triggers")).to eq(0)
      expect { database.execute("INSERT OR REPLACE INTO release_events VALUES (1, 1, 1, 'rewritten')") }
        .to raise_error(SQLite3::ConstraintException)
      expect(connection.select_value("SELECT name FROM release_events WHERE id = 1")).to eq("original")
    ensure
      database&.close
    end
  end

  it "removes only the new guards when rolling back" do
    with_legacy_database do |connection, migration|
      migration.suppress_messages do
        migration.up
        migration.down
      end

      expect { connection.execute("UPDATE release_events SET name = 'rewritten'") }.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
      expect { connection.execute("DELETE FROM release_events") }.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
      connection.execute("INSERT OR REPLACE INTO release_events VALUES (1, 1, 1, 'legacy-replacement')")
      expect(connection.select_value("SELECT name FROM release_events WHERE id = 1")).to eq("legacy-replacement")
    end
  end
end
