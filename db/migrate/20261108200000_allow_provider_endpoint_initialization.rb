class AllowProviderEndpointInitialization < ActiveRecord::Migration[8.1]
  def up
    execute "DROP TRIGGER provider_identity_no_update"
    execute <<~SQL.squish
      CREATE TRIGGER provider_identity_no_update BEFORE UPDATE OF role, provider, identity_key ON provider_connections
      BEGIN SELECT RAISE(ABORT, 'Provider identity is immutable'); END;
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER provider_endpoint_no_update BEFORE UPDATE OF endpoint ON provider_connections
      WHEN OLD.endpoint IS NOT NULL OR NEW.endpoint IS NULL
      BEGIN SELECT RAISE(ABORT, 'Provider endpoint is immutable once configured'); END;
    SQL
  end

  def down
    execute "DROP TRIGGER provider_endpoint_no_update"
    execute "DROP TRIGGER provider_identity_no_update"
    execute <<~SQL.squish
      CREATE TRIGGER provider_identity_no_update BEFORE UPDATE OF role, provider, identity_key, endpoint ON provider_connections
      BEGIN SELECT RAISE(ABORT, 'Provider identity is immutable'); END;
    SQL
  end
end
