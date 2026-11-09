require 'rails_helper'
require 'tmpdir'
require 'bcrypt'
require Rails.root.join('db/migrate/20261108180000_create_operator_access')
require Rails.root.join('db/migrate/20261108210000_use_devise_for_operator_access')

RSpec.describe UseDeviseForOperatorAccess do
  def with_legacy_database
    Dir.mktmpdir('seedbench-legacy-login-') do |directory|
      connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(adapter: 'sqlite3', database: File.join(directory, 'legacy.sqlite3'))
      legacy = CreateOperatorAccess.new
      migration = described_class.new
      legacy.suppress_messages { legacy.exec_migration(connection, :up) }
      digest = BCrypt::Password.create(OperatorHelpers::PASSWORD, cost: 4).to_s
      connection.execute("INSERT INTO operators (id, password_digest, created_at, updated_at) VALUES (1, #{connection.quote(digest)}, '2026-11-08', '2026-11-08')")
      connection.execute("INSERT INTO login_sessions (operator_id, token_digest, expires_at, created_at, updated_at) VALUES (1, 'old-session', '2026-11-09', '2026-11-08', '2026-11-08')")
      yield connection, migration, digest
    ensure
      connection&.disconnect!
    end
  end

  it 'retains the bcrypt hash and invalidates legacy sessions on upgrade' do
    with_legacy_database do |connection, migration, digest|
      migration.suppress_messages { migration.exec_migration(connection, :up) }
      encrypted_password = connection.select_value('SELECT encrypted_password FROM operators WHERE id = 1')

      expect(encrypted_password).to eq(digest)
      expect(Devise::Encryptor.compare(Operator, encrypted_password, OperatorHelpers::PASSWORD)).to be(true)
      expect(connection.table_exists?(:login_sessions)).to be(false)
      expect(connection.select_value('SELECT COUNT(*) FROM sessions')).to eq(0)
    end
  end

  it 'preserves the password and single-operator constraint through rollback and reapplication' do
    with_legacy_database do |connection, migration, digest|
      migration.suppress_messages do
        migration.exec_migration(connection, :up)
        migration.exec_migration(connection, :down)
      end
      expect(connection.select_value('SELECT password_digest FROM operators WHERE id = 1')).to eq(digest)
      expect { connection.execute("INSERT INTO operators (id, password_digest, created_at, updated_at) VALUES (2, 'other', '2026-11-08', '2026-11-08')") }.to raise_error(ActiveRecord::StatementInvalid)
      migration.suppress_messages { migration.exec_migration(connection, :up) }
      expect(connection.select_value('SELECT encrypted_password FROM operators WHERE id = 1')).to eq(digest)
    end
  end
end
