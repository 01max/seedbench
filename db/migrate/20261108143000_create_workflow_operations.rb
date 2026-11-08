class CreateWorkflowOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_operations do |t|
      t.references :release, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :request_key, null: false
      t.string :effect, null: false
      t.string :state, null: false, default: "pending"
      t.string :phase, null: false, default: "requested"
      t.integer :input_revision, null: false
      t.integer :attempts, null: false, default: 0
      t.json :parameters, null: false, default: {}
      t.json :result, null: false, default: {}
      t.json :external_reference, null: false, default: {}
      t.string :attempt_token
      t.datetime :lease_expires_at
      t.datetime :started_at
      t.datetime :finished_at
      t.string :error_code
      t.timestamps
    end
    add_index :workflow_operations, [ :release_id, :request_key ], unique: true
    add_index :workflow_operations, [ :release_id, :id ], unique: true
    add_index :workflow_operations, [ :state, :lease_expires_at ]
    add_check_constraint :workflow_operations, "input_revision >= 0 AND attempts >= 0", name: "operation_revisions_valid"
    add_check_constraint :workflow_operations, "length(request_key) BETWEEN 1 AND 80", name: "operation_request_key_valid"
    add_check_constraint :workflow_operations, "effect IN ('local', 'remote', 'filesystem')", name: "operation_effect_valid"
    add_check_constraint :workflow_operations, "state IN ('pending', 'running', 'succeeded', 'failed', 'stale', 'outcome_unknown')", name: "operation_state_valid"
    add_check_constraint :workflow_operations, "state != 'running' OR (attempt_token IS NOT NULL AND lease_expires_at IS NOT NULL)", name: "running_operation_has_attempt"
    %w[parameters result external_reference].each do |column|
      add_check_constraint :workflow_operations, "json_valid(#{column}) AND json_type(#{column}) = 'object'", name: "operation_#{column}_object"
    end

    create_table :dispatch_intents do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :workflow_operation_id, null: false
      t.string :state, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.string :dispatch_token
      t.datetime :claimed_until
      t.datetime :dispatched_at
      t.string :job_id
      t.string :error_code
      t.timestamps
    end
    add_index :dispatch_intents, :workflow_operation_id, unique: true
    add_index :dispatch_intents, [ :state, :claimed_until ]
    add_foreign_key :dispatch_intents, :workflow_operations, column: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ]
    add_check_constraint :dispatch_intents, "state IN ('pending', 'dispatching', 'dispatched') AND attempts >= 0", name: "dispatch_state_valid"
    add_check_constraint :dispatch_intents, "state != 'dispatching' OR (dispatch_token IS NOT NULL AND claimed_until IS NOT NULL)", name: "dispatch_claim_valid"
    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          CREATE TRIGGER operation_input_no_update BEFORE UPDATE OF release_id, kind, request_key, effect, input_revision, parameters ON workflow_operations
          BEGIN SELECT RAISE(ABORT, 'Operation inputs are immutable'); END;
        SQL
      end
    end
  end
end
