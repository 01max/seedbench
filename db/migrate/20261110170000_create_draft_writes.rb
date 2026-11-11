class CreateDraftWrites < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_writes do |table|
      table.references :release, null: false, foreign_key: true
      table.bigint :workflow_operation_id, null: false
      table.bigint :provider_connection_id, null: false
      table.string :provider_role, null: false, default: 'publishing'
      table.string :action, null: false
      table.string :remote_id
      table.string :state, null: false, default: 'pending'
      table.string :error_code
      table.json :request, null: false, default: {}
      table.json :body
      table.json :baseline_ids, null: false, default: []
      table.timestamps
    end
    add_foreign_key :draft_writes, :workflow_operations, column: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :draft_writes, :provider_connections, column: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_index :draft_writes, :workflow_operation_id, unique: true
    add_index :draft_writes, :release_id, unique: true, where: "state IN ('pending', 'sending', 'unknown')", name: 'one_active_draft_write'
    add_check_constraint :draft_writes, "action IN ('create', 'update', 'delete')", name: 'draft_write_action'
    add_check_constraint :draft_writes, "state IN ('pending', 'sending', 'accepted', 'failed', 'unknown')", name: 'draft_write_state'
    add_check_constraint :draft_writes, "provider_role = 'publishing' AND json_valid(request) AND json_type(request) = 'object'", name: 'draft_write_request'

    add_check_constraint :draft_writes, "body IS NULL OR (json_valid(body) AND json_type(body) = 'object')", name: 'draft_write_body'
    reversible do |direction|
      direction.up { install_guards }
      direction.down { %w[draft_writes_identity draft_writes_body draft_writes_remote draft_writes_no_delete draft_writes_no_replace].each { |name| execute "DROP TRIGGER #{name}" } }
    end
  end

  private

  def install_guards
    execute <<~SQL.squish
      CREATE TRIGGER draft_writes_identity BEFORE UPDATE OF release_id, workflow_operation_id, provider_connection_id, provider_role, action, request ON draft_writes
      BEGIN SELECT RAISE(ABORT, 'Draft request identity is immutable'); END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER draft_writes_body BEFORE UPDATE OF body, baseline_ids ON draft_writes WHEN OLD.body IS NOT NULL
      BEGIN SELECT RAISE(ABORT, 'Draft transmission is immutable'); END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER draft_writes_remote BEFORE UPDATE OF remote_id ON draft_writes WHEN OLD.remote_id IS NOT NULL AND NEW.remote_id IS NOT OLD.remote_id
      BEGIN SELECT RAISE(ABORT, 'Draft receipt identity is immutable'); END
    SQL
    execute "CREATE TRIGGER draft_writes_no_delete BEFORE DELETE ON draft_writes BEGIN SELECT RAISE(ABORT, 'Draft write history is retained'); END"
    execute <<~SQL.squish
      CREATE TRIGGER draft_writes_no_replace BEFORE INSERT ON draft_writes
      WHEN EXISTS (SELECT 1 FROM draft_writes WHERE id = NEW.id OR workflow_operation_id = NEW.workflow_operation_id)
      BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: draft_writes.id'); END
    SQL
  end
end
