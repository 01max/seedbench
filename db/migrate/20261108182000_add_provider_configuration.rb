class AddProviderConfiguration < ActiveRecord::Migration[8.1]
  def up
    preserving_triggers do
      add_column :provider_connections, :credentials, :text
      add_column :provider_connections, :options, :json, null: false, default: {}
      add_column :provider_connections, :credentials_version, :integer, null: false, default: 0
      add_column :provider_connections, :check_status, :string, null: false, default: 'untested'
      add_column :provider_connections, :check_code, :string
      add_column :provider_connections, :check_message, :string
      add_column :provider_connections, :checked_at, :datetime
      add_check_constraint :provider_connections, "json_valid(options) AND json_type(options) = 'object'", name: 'connection_options_object'
      add_check_constraint :provider_connections, 'credentials_version >= 0', name: 'connection_version_valid'
      add_check_constraint :provider_connections, "check_status IN ('untested', 'passed', 'limited', 'failed')", name: 'connection_check_valid'
    end
  end

  def down
    preserving_triggers do
      %w[connection_options_object connection_version_valid connection_check_valid].each do |name|
        remove_check_constraint :provider_connections, name: name
      end
      remove_columns :provider_connections, :credentials, :options, :credentials_version, :check_status, :check_code, :check_message, :checked_at
    end
  end

  private

  def preserving_triggers
    triggers = connection.select_values("SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'provider_connections'")
    yield
    triggers.each { |sql| execute sql.sub(/\ACREATE TRIGGER(?: IF NOT EXISTS)?/i, 'CREATE TRIGGER IF NOT EXISTS') }
  end
end
