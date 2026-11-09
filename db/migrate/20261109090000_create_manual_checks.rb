class CreateManualChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :manual_checks do |t|
      t.references :release, null: false, foreign_key: true
      t.string :key, null: false
      t.integer :number, null: false
      t.boolean :checked, null: false, default: false
      t.integer :input_revision, null: false
      t.string :actor, null: false
      t.timestamps
    end
    add_index :manual_checks, [ :release_id, :key, :number ], unique: true
    add_check_constraint :manual_checks, 'number > 0 AND input_revision >= 0', name: 'manual_check_revisions_valid'
    add_check_constraint :manual_checks, "key IN ('edition_review', 'text_review') AND actor = 'operator'", name: 'manual_check_owner_valid'
    add_check_constraint :manual_checks, 'checked IN (0, 1)', name: 'manual_check_boolean_valid'
    reversible do |direction|
      direction.up { add_history_guards }
    end
  end

  private

  def add_history_guards
    %w[UPDATE DELETE].each do |operation|
      execute "CREATE TRIGGER manual_checks_no_#{operation.downcase} BEFORE #{operation} ON manual_checks BEGIN SELECT RAISE(ABORT, 'Checklist history is append-only'); END;"
    end
    execute <<~SQL.squish
      CREATE TRIGGER manual_checks_no_replace BEFORE INSERT ON manual_checks
      WHEN EXISTS (SELECT 1 FROM manual_checks WHERE id = NEW.id OR (release_id = NEW.release_id AND key = NEW.key AND number = NEW.number))
      BEGIN SELECT RAISE(ABORT, 'Checklist history is append-only'); END;
    SQL
  end
end
