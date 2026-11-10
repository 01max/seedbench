class CreatePayloadMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :payload_moves do |table|
      table.references :release, null: false, foreign_key: true
      table.bigint :payload_revision_id, null: false
      table.bigint :workflow_operation_id, null: false
      table.string :source_locator, null: false
      table.string :destination_locator, null: false
      table.bigint :source_device, null: false
      table.bigint :source_inode, null: false
      table.bigint :root_device, null: false
      table.bigint :root_inode, null: false
      table.string :state, null: false, default: 'reserved'
      table.timestamps null: false
    end
    add_foreign_key :payload_moves, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :payload_moves, :workflow_operations, column: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ]
    add_index :payload_moves, :workflow_operation_id, unique: true
    add_index :payload_moves, :destination_locator, unique: true, where: "state IN ('reserved', 'moved')", name: 'active_payload_destination'
    add_check_constraint :payload_moves, "state IN ('reserved', 'moved', 'completed', 'cancelled')", name: 'payload_move_state'
    %w[source_locator destination_locator].each do |field|
      add_check_constraint :payload_moves, "length(#{field}) > 0 AND substr(#{field}, 1, 1) != '/'", name: "payload_move_#{field}"
    end
    reversible do |direction|
      direction.up { install_guards }
      direction.down { %w[input delete replace].each { |name| execute "DROP TRIGGER payload_moves_no_#{name}" } }
    end
  end

  private

  def install_guards
    execute <<~SQL.squish
      CREATE TRIGGER payload_moves_no_input BEFORE UPDATE OF release_id, payload_revision_id, workflow_operation_id,
        source_locator, destination_locator, source_device, source_inode, root_device, root_inode ON payload_moves
      BEGIN SELECT RAISE(ABORT, 'Move identity is immutable'); END
    SQL
    execute "CREATE TRIGGER payload_moves_no_delete BEFORE DELETE ON payload_moves BEGIN SELECT RAISE(ABORT, 'Move journal is retained'); END"
    execute <<~SQL.squish
      CREATE TRIGGER payload_moves_no_replace BEFORE INSERT ON payload_moves
      WHEN EXISTS (SELECT 1 FROM payload_moves WHERE id = NEW.id OR workflow_operation_id = NEW.workflow_operation_id
        OR (destination_locator = NEW.destination_locator AND state IN ('reserved', 'moved') AND NEW.state IN ('reserved', 'moved')))
      BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: payload_moves.destination_locator'); END
    SQL
  end
end
