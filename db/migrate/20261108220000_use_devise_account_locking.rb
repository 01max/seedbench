class UseDeviseAccountLocking < ActiveRecord::Migration[8.1]
  def change
    add_column :operators, :failed_attempts, :integer, default: 0, null: false
    add_column :operators, :locked_at, :datetime

    drop_table :login_throttles do |table|
      table.string :client_hash, null: false
      table.integer :attempts, null: false, default: 0
      table.datetime :window_started_at, null: false
      table.timestamps
      table.index :client_hash, unique: true
      table.check_constraint 'attempts >= 0', name: 'login_attempts_valid'
    end
  end
end
