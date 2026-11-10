class RecordAiRequestProvenance < ActiveRecord::Migration[8.1]
  def up
    add_column :ai_runs, :request, :json, null: false, default: {}
    add_column :ai_runs, :workflow_operation_id, :bigint
    add_foreign_key :ai_runs, :workflow_operations, column: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ]
    add_index :ai_runs, :workflow_operation_id, unique: true
    add_index :ai_runs, [ :release_id, :purpose ], unique: true, where: "workflow_operation_id IS NOT NULL AND status IN ('pending', 'running')", name: 'one_active_ai_run'
    add_check_constraint :ai_runs, "json_valid(request) AND json_type(request) = 'object'", name: 'ai_request_object'
    add_check_constraint :ai_runs, "result IS NULL OR (json_valid(result) AND json_type(result) = 'object')", name: 'ai_result_object'
    install_guards
  end

  def down
    %w[ai_runs_identity ai_runs_terminal ai_runs_no_delete ai_runs_no_replace].each { |name| execute "DROP TRIGGER #{name}" }
    remove_foreign_key :ai_runs, column: [ :release_id, :workflow_operation_id ]
    remove_index :ai_runs, name: 'one_active_ai_run'
    remove_column :ai_runs, :workflow_operation_id
    remove_column :ai_runs, :request
  end

  private

  def install_guards
    execute <<~SQL.squish
      CREATE TRIGGER ai_runs_identity BEFORE UPDATE OF release_id, provider_connection_id, provider_role, input_revision, purpose, prompt_version, model, evidence_keys, workflow_operation_id, request ON ai_runs
      BEGIN SELECT RAISE(ABORT, 'AI run identity is immutable'); END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER ai_runs_terminal BEFORE UPDATE ON ai_runs WHEN OLD.status IN ('succeeded', 'failed', 'unusable', 'stale')
      BEGIN SELECT RAISE(ABORT, 'AI result history is immutable'); END
    SQL
    execute "CREATE TRIGGER ai_runs_no_delete BEFORE DELETE ON ai_runs BEGIN SELECT RAISE(ABORT, 'AI run history is retained'); END"
    execute <<~SQL.squish
      CREATE TRIGGER ai_runs_no_replace BEFORE INSERT ON ai_runs
      WHEN EXISTS (SELECT 1 FROM ai_runs WHERE id = NEW.id OR workflow_operation_id = NEW.workflow_operation_id)
      BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: ai_runs.id'); END
    SQL
  end
end
