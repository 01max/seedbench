class CreateDraftLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_links do |table|
      table.references :release, null: false, foreign_key: true, index: { unique: true }
      table.bigint :provider_connection_id, null: false
      table.string :provider_role, null: false, default: 'publishing'
      table.string :remote_id, null: false
      table.timestamps
    end
    add_foreign_key :draft_links, :provider_connections, column: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_index :draft_links, [ :provider_connection_id, :remote_id ], unique: true
    add_check_constraint :draft_links, "provider_role = 'publishing'", name: 'draft_link_publishing'
    add_check_constraint :draft_links, 'length(remote_id) BETWEEN 1 AND 100', name: 'draft_link_identity'
  end
end
