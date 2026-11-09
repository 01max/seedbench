require 'rails_helper'
require 'tmpdir'

RSpec.describe Seedbench::SqliteDatabaseTasks do
  def loader_for(path)
    config = ActiveRecord::DatabaseConfigurations::HashConfig.new('test', 'schema_probe', adapter: 'sqlite3', database: path)
    described_class.new(config, Rails.root)
  end

  it 'loads a SQL schema using literal database and source paths containing spaces' do
    Dir.mktmpdir('seedbench schema ') do |directory|
      database = File.join(directory, 'state with spaces;literal.sqlite3')
      source = File.join(directory, 'schema with "quotes".sql')
      File.write(source, "CREATE TABLE schema_probe (id INTEGER PRIMARY KEY);\n")
      loader_for(database).structure_load(source, [])
      connection = SQLite3::Database.new(database, readonly: true)
      expect(connection.get_first_value("SELECT name FROM sqlite_master WHERE name = 'schema_probe'")).to eq('schema_probe')
      connection.close
    end
  end

  it 'fails the command when the SQL schema cannot be loaded' do
    Dir.mktmpdir('seedbench schema ') do |directory|
      database = File.join(directory, 'state.sqlite3')
      source = File.join(directory, 'invalid.sql')
      File.write(source, "INVALID SQL;\n")

      expect do
        expect { loader_for(database).structure_load(source, []) }.to raise_error(RuntimeError, /failed to execute/)
      end.to output(/syntax error/).to_stderr_from_any_process
    end
  end
end
