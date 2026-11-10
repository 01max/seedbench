class AddCoverVerification < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE cover_hostings ADD COLUMN verification json NOT NULL DEFAULT '{}' CHECK (json_valid(verification) AND json_type(verification) = 'object')"
    create_table :cover_uploads do |table|
      table.references :release, null: false, foreign_key: true
      table.bigint :workflow_operation_id, null: false
      table.bigint :cover_revision_id, null: false
      table.bigint :provider_connection_id, null: false
      table.string :provider_role, null: false, default: 'image_host'
      table.string :source_sha256, null: false
      table.string :state, null: false, default: 'pending'
      table.string :page_url
      table.string :direct_url
      table.string :failure_code
      table.timestamps null: false
    end
    add_foreign_key :cover_uploads, :workflow_operations, column: [ :release_id, :workflow_operation_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :cover_uploads, :cover_revisions, column: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :cover_uploads, :provider_connections, column: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_index :cover_uploads, :workflow_operation_id, unique: true
    add_index :cover_uploads, [ :release_id, :cover_revision_id, :provider_connection_id ], unique: true,
      where: "state IN ('pending', 'outcome_unknown')", name: 'one_uncertain_cover_upload'
    add_check_constraint :cover_uploads, "provider_role = 'image_host'", name: 'cover_upload_role'
    add_check_constraint :cover_uploads, "state IN ('pending', 'uploaded', 'verified', 'failed', 'outcome_unknown')", name: 'cover_upload_state'
    add_check_constraint :cover_uploads, "length(source_sha256) = 64 AND source_sha256 NOT GLOB '*[^0-9a-f]*'", name: 'cover_upload_source'
    install_guards
  end

  def down
    drop_table :cover_uploads
    execute 'ALTER TABLE cover_hostings DROP COLUMN verification'
  end

  private

  def install_guards
    execute <<~SQL.squish
      CREATE TRIGGER cover_uploads_identity BEFORE UPDATE OF release_id, workflow_operation_id, cover_revision_id, provider_connection_id, provider_role, source_sha256 ON cover_uploads
      BEGIN SELECT RAISE(ABORT, 'Upload identity is immutable'); END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER cover_uploads_receipt BEFORE UPDATE OF page_url, direct_url ON cover_uploads
      WHEN (OLD.page_url IS NOT NULL AND NEW.page_url IS NOT OLD.page_url) OR (OLD.direct_url IS NOT NULL AND NEW.direct_url IS NOT OLD.direct_url)
      BEGIN SELECT RAISE(ABORT, 'Upload receipt is immutable'); END
    SQL
    execute "CREATE TRIGGER cover_uploads_no_delete BEFORE DELETE ON cover_uploads BEGIN SELECT RAISE(ABORT, 'Upload history is retained'); END"
    execute <<~SQL.squish
      CREATE TRIGGER cover_uploads_no_replace BEFORE INSERT ON cover_uploads
      WHEN EXISTS (SELECT 1 FROM cover_uploads WHERE id = NEW.id OR workflow_operation_id = NEW.workflow_operation_id
        OR (release_id = NEW.release_id AND cover_revision_id = NEW.cover_revision_id AND provider_connection_id = NEW.provider_connection_id
          AND state IN ('pending', 'outcome_unknown') AND NEW.state IN ('pending', 'outcome_unknown')))
      BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: cover_uploads.workflow_operation_id'); END
    SQL
  end
end
