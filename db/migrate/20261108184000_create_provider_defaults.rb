class CreateProviderDefaults < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_preferences do |t|
      t.boolean :automatic_ai, null: false, default: true
      t.integer :revision, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :operator_preferences, "id = 1 AND revision >= 0 AND automatic_ai IN (0, 1)", name: "operator_preferences_valid"

    create_table :provider_defaults do |t|
      t.string :role, null: false
      t.bigint :provider_connection_id
      t.timestamps
    end
    add_index :provider_defaults, :role, unique: true
    add_check_constraint :provider_defaults, "role IN ('publishing', 'torrent_client', 'ai', 'image_host')", name: "default_role_valid"
    add_foreign_key :provider_defaults, :provider_connections, column: [ :role, :provider_connection_id ], primary_key: [ :role, :id ]
  end
end
