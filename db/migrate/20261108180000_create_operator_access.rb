class CreateOperatorAccess < ActiveRecord::Migration[8.1]
  def change
    create_table :operators do |t|
      t.string :password_digest, null: false
      t.timestamps
    end
    add_check_constraint :operators, "id = 1", name: "single_operator"

    create_table :login_sessions do |t|
      t.references :operator, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :login_sessions, :token_digest, unique: true

    create_table :login_throttles do |t|
      t.string :client_hash, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :window_started_at, null: false
      t.timestamps
    end
    add_index :login_throttles, :client_hash, unique: true
    add_check_constraint :login_throttles, "attempts >= 0", name: "login_attempts_valid"
  end
end
