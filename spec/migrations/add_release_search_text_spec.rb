require "rails_helper"
require "tmpdir"
require Rails.root.join("db/migrate/20261109100000_add_release_search_text")

RSpec.describe AddReleaseSearchText do
  def with_legacy_database
    Dir.mktmpdir("seedbench-search-") do |directory|
      connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(adapter: "sqlite3", database: File.join(directory, "legacy.sqlite3"))
      connection.create_table(:releases) { |table| table.string(:title); table.string(:author) }
      connection.execute("INSERT INTO releases (id, title, author) VALUES (1, 'Édition', 'Émile')")
      migration = described_class.new
      yield connection, migration
    ensure
      connection&.disconnect!
    end
  end

  it "backfills normalized search without changing the original title or author" do
    with_legacy_database do |connection, migration|
      migration.suppress_messages { migration.exec_migration(connection, :up) }

      expect(connection.select_value("SELECT search_text FROM releases WHERE id = 1")).to eq("edition emile")
      expect(connection.select_value("SELECT title FROM releases WHERE id = 1")).to eq("Édition")
    end
  end

  it "retains release identity through rollback and reapplication" do
    with_legacy_database do |connection, migration|
      migration.suppress_messages do
        migration.exec_migration(connection, :up)
        migration.exec_migration(connection, :down)
        migration.exec_migration(connection, :up)
      end

      expect(connection.select_value("SELECT author FROM releases WHERE id = 1")).to eq("Émile")
      expect(connection.select_value("SELECT search_text FROM releases WHERE id = 1")).to eq("edition emile")
    end
  end
end
