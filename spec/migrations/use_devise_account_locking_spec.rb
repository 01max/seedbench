require 'rails_helper'
require 'tmpdir'
require Rails.root.join('db/migrate/20261108180000_create_operator_access')
require Rails.root.join('db/migrate/20261108210000_use_devise_for_operator_access')
require Rails.root.join('db/migrate/20261108220000_use_devise_account_locking')

RSpec.describe UseDeviseAccountLocking do
  def with_existing_database
    Dir.mktmpdir('seedbench-account-locking-') do |directory|
      connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(adapter: 'sqlite3', database: File.join(directory, 'existing.sqlite3'))
      [ CreateOperatorAccess.new, UseDeviseForOperatorAccess.new ].each do |migration|
        migration.suppress_messages { migration.exec_migration(connection, :up) }
      end
      connection.execute("INSERT INTO operators (id, encrypted_password, created_at, updated_at) VALUES (1, 'retained-hash', '2026-11-08', '2026-11-08')")
      connection.execute("INSERT INTO sessions (session_id, data, created_at, updated_at) VALUES ('retained-session', '{}', '2026-11-08', '2026-11-08')")
      connection.execute("INSERT INTO login_throttles (client_hash, attempts, window_started_at, created_at, updated_at) VALUES ('old-peer', 10, '2026-11-08', '2026-11-08', '2026-11-08')")
      yield connection, described_class.new
    ensure
      connection&.disconnect!
    end
  end

  it "preserves the password and sessions while initializing Devise's lock state" do
    with_existing_database do |connection, migration|
      migration.suppress_messages { migration.exec_migration(connection, :up) }

      expect(connection.select_one('SELECT encrypted_password, failed_attempts, locked_at FROM operators')).to eq(
        'encrypted_password' => 'retained-hash', 'failed_attempts' => 0, 'locked_at' => nil)
      expect(connection.select_value('SELECT session_id FROM sessions')).to eq('retained-session')
      expect(connection.table_exists?(:login_throttles)).to be(false)
    end
  end

  it 'retains the single-operator constraint through rollback and reapplication' do
    with_existing_database do |connection, migration|
      migration.suppress_messages do
        migration.exec_migration(connection, :up)
        migration.exec_migration(connection, :down)
        migration.exec_migration(connection, :up)
      end

      expect(connection.select_value('SELECT encrypted_password FROM operators')).to eq('retained-hash')
      expect { connection.execute("INSERT INTO operators (id, encrypted_password, created_at, updated_at) VALUES (2, 'other', '2026-11-08', '2026-11-08')") }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  it 'restores the legacy throttle constraints on rollback' do
    with_existing_database do |connection, migration|
      migration.suppress_messages do
        migration.exec_migration(connection, :up)
        migration.exec_migration(connection, :down)
      end

      expect(connection.columns(:operators).map(&:name)).not_to include('failed_attempts', 'locked_at')
      expect(connection.indexes(:login_throttles).find { |index| index.columns == [ 'client_hash' ] }.unique).to be(true)
      expect { connection.execute("INSERT INTO login_throttles (client_hash, attempts, window_started_at, created_at, updated_at) VALUES ('invalid', -1, '2026-11-08', '2026-11-08', '2026-11-08')") }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
