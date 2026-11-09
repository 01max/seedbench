require 'rails_helper'
require 'tmpdir'
require Rails.root.join('db/migrate/20261108200000_allow_provider_endpoint_initialization')

RSpec.describe AllowProviderEndpointInitialization do
  def with_legacy_database
    Dir.mktmpdir('seedbench-legacy-provider-') do |directory|
      connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(adapter: 'sqlite3', database: File.join(directory, 'legacy.sqlite3'))
      connection.create_table(:provider_connections) { |table| %i[role provider identity_key endpoint].each { |column| table.string(column) } }
      connection.execute("CREATE TRIGGER provider_identity_no_update BEFORE UPDATE OF role, provider, identity_key, endpoint ON provider_connections BEGIN SELECT RAISE(ABORT, 'Provider identity is immutable'); END")
      connection.execute("CREATE TRIGGER legacy_no_replace BEFORE INSERT ON provider_connections WHEN EXISTS (SELECT 1 FROM provider_connections WHERE id = NEW.id) BEGIN SELECT RAISE(ABORT, 'No replacement'); END")
      connection.execute("INSERT INTO provider_connections (id, role, provider, identity_key) VALUES (1, 'publishing', 'c411', 'legacy-account')")
      migration = described_class.new
      allow(migration).to receive(:connection).and_return(connection)
      yield connection, migration
    ensure
      connection&.disconnect!
    end
  end

  it 'fills an absent endpoint once and prevents changing or clearing the recorded address' do
    with_legacy_database do |connection, migration|
      migration.suppress_messages { migration.up }
      connection.execute("UPDATE provider_connections SET endpoint = 'https://c411.org' WHERE id = 1")

      expect { connection.execute("UPDATE provider_connections SET endpoint = 'https://different.invalid' WHERE id = 1") }.to raise_error(ActiveRecord::StatementInvalid)
      expect { connection.execute('UPDATE provider_connections SET endpoint = NULL WHERE id = 1') }.to raise_error(ActiveRecord::StatementInvalid)
      expect(connection.select_value('SELECT endpoint FROM provider_connections WHERE id = 1')).to eq('https://c411.org')
    end
  end

  it 'retains identity and replacement guards while the endpoint is still absent' do
    with_legacy_database do |connection, migration|
      migration.suppress_messages { migration.up }

      %w[role provider identity_key].each do |column|
        expect { connection.execute("UPDATE provider_connections SET #{column} = 'different' WHERE id = 1") }.to raise_error(ActiveRecord::StatementInvalid)
      end
      expect { connection.execute('INSERT OR REPLACE INTO provider_connections (id) VALUES (1)') }.to raise_error(ActiveRecord::StatementInvalid, /No replacement/)
      expect(connection.select_value('SELECT identity_key FROM provider_connections WHERE id = 1')).to eq('legacy-account')
    end
  end

  it 'restores the original guard without removing data or unrelated triggers on rollback' do
    with_legacy_database do |connection, migration|
      migration.suppress_messages do
        migration.up
        migration.down
      end

      expect { connection.execute("UPDATE provider_connections SET endpoint = 'https://c411.org' WHERE id = 1") }.to raise_error(ActiveRecord::StatementInvalid)
      expect { connection.execute("UPDATE provider_connections SET identity_key = 'different' WHERE id = 1") }.to raise_error(ActiveRecord::StatementInvalid)
      expect { connection.execute('INSERT OR REPLACE INTO provider_connections (id) VALUES (1)') }.to raise_error(ActiveRecord::StatementInvalid, /No replacement/)
      expect(connection.select_value('SELECT identity_key FROM provider_connections WHERE id = 1')).to eq('legacy-account')
    end
  end
end
