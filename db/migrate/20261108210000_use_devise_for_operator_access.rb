class UseDeviseForOperatorAccess < ActiveRecord::Migration[8.1]
  def change
    rename_column :operators, :password_digest, :encrypted_password

    drop_table :login_sessions do |table|
      table.references :operator, null: false, foreign_key: true
      table.string :token_digest, null: false
      table.datetime :expires_at, null: false
      table.timestamps
      table.index :token_digest, unique: true
    end

    create_table :sessions do |table|
      table.string :session_id, null: false
      table.text :data
      table.timestamps
      table.index :session_id, unique: true
      table.index :created_at
      table.index :updated_at
    end
  end
end
