class CreateReleaseState < ActiveRecord::Migration[8.1]
  def change
    create_table :releases do |t|
      t.string :title
      t.string :author
      t.string :proposed_name
      t.boolean :automatic_ai, null: false, default: true
      t.integer :input_revision, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.string :inspection_state, null: false, default: "pending"
      t.string :preparation_state, null: false, default: "unprepared"
      t.string :draft_state, null: false, default: "unlinked"
      t.string :publication_state, null: false, default: "unpublished"
      t.string :seeding_state, null: false, default: "not_started"
      t.timestamps
    end

    create_table :provider_connections do |t|
      t.string :role, null: false
      t.string :provider, null: false
      t.string :identity_key, null: false
      t.string :label, null: false
      t.string :endpoint
      t.timestamps
    end

    create_table :payload_revisions do |t|
      t.references :release, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :original_filename, null: false
      t.string :format, null: false
      t.bigint :size_bytes, null: false
      t.string :sha256, null: false
      t.string :locator, null: false
      t.timestamps
    end
    add_index :payload_revisions, [ :release_id, :id ], unique: true

    create_table :preparation_revisions do |t|
      t.references :release, null: false, foreign_key: true
      t.integer :number, null: false
      t.bigint :payload_revision_id, null: false
      t.string :release_name, null: false
      t.string :payload_name, null: false
      t.string :torrent_locator, null: false
      t.string :torrent_info_hash, null: false
      t.string :payload_sha256, null: false
      t.bigint :payload_size_bytes, null: false
      t.string :policy_version, null: false
      t.datetime :prepared_at, null: false
      t.timestamps
    end
    add_index :preparation_revisions, [ :release_id, :id ], unique: true

    create_table :evidence_items do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :payload_revision_id, null: false
      t.string :evidence_key, null: false
      t.string :kind, null: false
      t.string :source, null: false
      t.datetime :captured_at, null: false
      t.integer :input_revision, null: false
      t.json :data, null: false, default: {}
      t.timestamps
    end
    add_index :evidence_items, [ :release_id, :id ], unique: true

    create_table :reviewed_facts do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :payload_revision_id, null: false
      t.string :field, null: false
      t.integer :number, null: false
      t.json :value, null: false
      t.string :actor, null: false
      t.datetime :reviewed_at, null: false
      t.timestamps
    end
    add_index :reviewed_facts, [ :release_id, :id ], unique: true

    create_table :fact_evidence_links do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :reviewed_fact_id, null: false
      t.bigint :evidence_item_id, null: false
      t.timestamps
    end
    add_index :fact_evidence_links, [ :release_id, :id ], unique: true

    create_table :findings do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :payload_revision_id, null: false
      t.string :code, null: false
      t.integer :number, null: false
      t.string :severity, null: false
      t.text :message, null: false
      t.integer :input_revision, null: false
      t.json :data, null: false, default: {}
      t.timestamps
    end
    add_index :findings, [ :release_id, :id ], unique: true

    create_table :finding_acknowledgements do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :finding_id, null: false
      t.boolean :acknowledged, null: false, default: false
      t.string :actor, null: false
      t.text :note
      t.timestamps
    end
    add_index :finding_acknowledgements, [ :release_id, :id ], unique: true

    create_table :cover_revisions do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :payload_revision_id
      t.integer :number, null: false
      t.string :source_kind, null: false
      t.string :source_locator, null: false
      t.integer :width
      t.integer :height
      t.json :edition_evidence, null: false, default: {}
      t.timestamps
    end
    add_index :cover_revisions, [ :release_id, :id ], unique: true

    create_table :cover_hostings do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :cover_revision_id, null: false
      t.bigint :provider_connection_id, null: false
      t.string :provider_role, null: false, default: "image_host"
      t.string :direct_url, null: false
      t.string :media_type, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.datetime :verified_at, null: false
      t.timestamps
    end
    add_index :cover_hostings, [ :release_id, :id ], unique: true

    create_table :content_revisions do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :payload_revision_id
      t.bigint :preparation_revision_id
      t.bigint :cover_revision_id
      t.string :kind, null: false
      t.integer :number, null: false
      t.text :body, null: false
      t.string :origin, null: false
      t.integer :input_revision, null: false
      t.json :dependencies, null: false, default: {}
      t.timestamps
    end
    add_index :content_revisions, [ :release_id, :id ], unique: true

    create_table :duplicate_checks do |t|
      t.references :release, null: false, foreign_key: true
      t.integer :input_revision, null: false
      t.json :query, null: false, default: {}
      t.json :candidates, null: false, default: []
      t.datetime :searched_at, null: false
      t.timestamps
    end
    add_index :duplicate_checks, [ :release_id, :id ], unique: true

    create_table :duplicate_decisions do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :duplicate_check_id, null: false
      t.string :candidate_key, null: false
      t.string :decision, null: false
      t.text :reason
      t.string :actor, null: false
      t.datetime :reviewed_at, null: false
      t.timestamps
    end
    add_index :duplicate_decisions, [ :release_id, :id ], unique: true

    create_table :remote_snapshots do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :provider_connection_id, null: false
      t.string :provider_role, null: false, default: "publishing"
      t.string :kind, null: false
      t.string :remote_id, null: false
      t.string :remote_revision
      t.integer :local_revision, null: false
      t.json :base_content, null: false, default: {}
      t.json :remote_content, null: false, default: {}
      t.boolean :remote_deleted, null: false, default: false
      t.datetime :observed_at, null: false
      t.timestamps
    end
    add_index :remote_snapshots, [ :release_id, :id ], unique: true

    create_table :ai_runs do |t|
      t.references :release, null: false, foreign_key: true
      t.bigint :provider_connection_id, null: false
      t.string :provider_role, null: false, default: "ai"
      t.integer :input_revision, null: false
      t.string :purpose, null: false
      t.string :prompt_version, null: false
      t.string :model, null: false
      t.json :evidence_keys, null: false, default: []
      t.string :status, null: false, default: "pending"
      t.json :result
      t.string :error_code
      t.timestamps
    end
    add_index :ai_runs, [ :release_id, :id ], unique: true

    create_table :provider_assignments do |t|
      t.references :release, null: false, foreign_key: true
      t.string :role, null: false
      t.bigint :provider_connection_id
      t.datetime :assigned_at
      t.timestamps
    end
    add_index :provider_assignments, [ :release_id, :id ], unique: true

    create_table :release_events do |t|
      t.references :release, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.string :name, null: false
      t.string :actor, null: false
      t.integer :input_revision, null: false
      t.json :data, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :release_events, [ :release_id, :id ], unique: true
    add_index :payload_revisions, [ :release_id, :id, :sha256, :size_bytes ], unique: true, name: "payload_identity_key"
    add_foreign_key :preparation_revisions, :payload_revisions,
      column: [ :release_id, :payload_revision_id, :payload_sha256, :payload_size_bytes ],
      primary_key: [ :release_id, :id, :sha256, :size_bytes ]
    add_index :provider_connections, [ :role, :identity_key ], unique: true
    add_index :provider_connections, [ :role, :id ], unique: true
    add_index :payload_revisions, [ :release_id, :number ], unique: true
    add_index :preparation_revisions, [ :release_id, :number ], unique: true
    add_index :cover_revisions, [ :release_id, :number ], unique: true
    add_index :evidence_items, [ :release_id, :evidence_key ], unique: true
    add_index :reviewed_facts, [ :release_id, :field, :number ], unique: true
    add_index :fact_evidence_links, [ :reviewed_fact_id, :evidence_item_id ], unique: true
    add_index :findings, [ :release_id, :code, :number ], unique: true
    add_index :content_revisions, [ :release_id, :kind, :number ], unique: true
    add_index :duplicate_decisions, [ :duplicate_check_id, :candidate_key ], unique: true
    add_index :provider_assignments, [ :release_id, :role ], unique: true
    add_index :release_events, [ :release_id, :sequence ], unique: true
    add_foreign_key :preparation_revisions, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :evidence_items, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :reviewed_facts, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :fact_evidence_links, :reviewed_facts, column: [ :release_id, :reviewed_fact_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :fact_evidence_links, :evidence_items, column: [ :release_id, :evidence_item_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :findings, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :finding_acknowledgements, :findings, column: [ :release_id, :finding_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :cover_revisions, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :cover_hostings, :cover_revisions, column: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :content_revisions, :payload_revisions, column: [ :release_id, :payload_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :content_revisions, :preparation_revisions, column: [ :release_id, :preparation_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :content_revisions, :cover_revisions, column: [ :release_id, :cover_revision_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :duplicate_decisions, :duplicate_checks, column: [ :release_id, :duplicate_check_id ], primary_key: [ :release_id, :id ]
    add_foreign_key :cover_hostings, :provider_connections, column: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_foreign_key :remote_snapshots, :provider_connections, column: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_foreign_key :ai_runs, :provider_connections, column: [ :provider_role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_foreign_key :provider_assignments, :provider_connections, column: [ :role, :provider_connection_id ], primary_key: [ :role, :id ]
    add_check_constraint :releases, %q(inspection_state IN ('pending', 'running', 'succeeded', 'failed')), name: "releases_inspection_state"
    add_check_constraint :releases, %q(preparation_state IN ('unprepared', 'running', 'prepared', 'stale', 'failed')), name: "releases_preparation_state"
    add_check_constraint :releases, %q(draft_state IN ('unlinked', 'synced', 'conflicted', 'missing')), name: "releases_draft_state"
    add_check_constraint :releases, %q(publication_state IN ('unpublished', 'submitting', 'published', 'outcome_unknown', 'failed')), name: "releases_publication_state"
    add_check_constraint :releases, %q(seeding_state IN ('not_started', 'checking', 'seeding', 'succeeded', 'failed', 'unknown')), name: "releases_seeding_state"
    add_check_constraint :releases, "input_revision >= 0 AND lock_version >= 0", name: "release_revisions_nonnegative"
    add_check_constraint :provider_connections, %q((role = 'publishing' AND provider = 'c411') OR (role = 'torrent_client' AND provider = 'deluge') OR (role = 'ai' AND provider = 'openai') OR (role = 'image_host' AND provider = 'postimages')), name: "provider_role_matches"
    add_check_constraint :cover_hostings, %q(provider_role = 'image_host'), name: "cover_hostings_provider_role"
    add_check_constraint :remote_snapshots, %q(provider_role = 'publishing'), name: "remote_snapshots_provider_role"
    add_check_constraint :ai_runs, %q(provider_role = 'ai'), name: "ai_runs_provider_role"
    add_check_constraint :provider_assignments, %q(role IN ('publishing', 'torrent_client', 'ai', 'image_host')), name: "provider_assignments_role"
    add_check_constraint :payload_revisions, "number > 0", name: "payload_revisions_number_positive"
    add_check_constraint :preparation_revisions, "number > 0", name: "preparation_revisions_number_positive"
    add_check_constraint :evidence_items, "input_revision >= 0", name: "evidence_items_input_nonnegative"
    add_check_constraint :evidence_items, %q(json_valid(data) AND json_type(data) = 'object'), name: "evidence_items_data_object"
    add_check_constraint :reviewed_facts, "number > 0", name: "reviewed_facts_number_positive"
    add_check_constraint :findings, "number > 0", name: "findings_number_positive"
    add_check_constraint :findings, "input_revision >= 0", name: "findings_input_nonnegative"
    add_check_constraint :findings, %q(json_valid(data) AND json_type(data) = 'object'), name: "findings_data_object"
    add_check_constraint :cover_revisions, "number > 0", name: "cover_revisions_number_positive"
    add_check_constraint :cover_revisions, %q(json_valid(edition_evidence) AND json_type(edition_evidence) = 'object'), name: "cover_revisions_edition_evidence_object"
    add_check_constraint :content_revisions, "number > 0", name: "content_revisions_number_positive"
    add_check_constraint :content_revisions, "input_revision >= 0", name: "content_revisions_input_nonnegative"
    add_check_constraint :content_revisions, %q(json_valid(dependencies) AND json_type(dependencies) = 'object'), name: "content_revisions_dependencies_object"
    add_check_constraint :duplicate_checks, "input_revision >= 0", name: "duplicate_checks_input_nonnegative"
    add_check_constraint :duplicate_checks, %q(json_valid(query) AND json_type(query) = 'object'), name: "duplicate_checks_query_object"
    add_check_constraint :duplicate_checks, %q(json_valid(candidates) AND json_type(candidates) = 'array'), name: "duplicate_checks_candidates_array"
    add_check_constraint :remote_snapshots, %q(json_valid(base_content) AND json_type(base_content) = 'object'), name: "remote_snapshots_base_content_object"
    add_check_constraint :remote_snapshots, %q(json_valid(remote_content) AND json_type(remote_content) = 'object'), name: "remote_snapshots_remote_content_object"
    add_check_constraint :ai_runs, "input_revision >= 0", name: "ai_runs_input_nonnegative"
    add_check_constraint :ai_runs, %q(json_valid(evidence_keys) AND json_type(evidence_keys) = 'array'), name: "ai_runs_evidence_keys_array"
    add_check_constraint :release_events, "input_revision >= 0", name: "release_events_input_nonnegative"
    add_check_constraint :release_events, %q(json_valid(data) AND json_type(data) = 'object'), name: "release_events_data_object"
    add_check_constraint :payload_revisions, %q(format IN ('epub', 'pdf', 'mobi')), name: "payload_revisions_format"
    add_check_constraint :payload_revisions, %q(size_bytes > 0 AND length(sha256) = 64 AND sha256 NOT GLOB '*[^0-9a-f]*'), name: "payload_identity_valid"
    add_check_constraint :payload_revisions, %q(length(locator) > 0 AND substr(locator, 1, 1) != '/'), name: "payload_locator_relative"
    add_check_constraint :preparation_revisions, "payload_size_bytes > 0 AND length(payload_sha256) = 64 AND length(torrent_info_hash) = 40", name: "preparation_identity_valid"
    add_check_constraint :findings, %q(severity IN ('failure', 'uncertainty', 'info')), name: "findings_severity"
    add_check_constraint :cover_revisions, %q(source_kind IN ('embedded', 'remote', 'manual')), name: "cover_revisions_source_kind"
    add_check_constraint :cover_revisions, "(width IS NULL OR width > 0) AND (height IS NULL OR height > 0)", name: "cover_dimensions_positive"
    add_check_constraint :cover_hostings, "width > 0 AND height > 0", name: "hosted_dimensions_positive"
    add_check_constraint :content_revisions, %q(kind IN ('bbcode', 'nfo', 'presentation', 'notes')), name: "content_revisions_kind"
    add_check_constraint :content_revisions, %q(origin IN ('human', 'generated', 'ai')), name: "content_revisions_origin"
    add_check_constraint :duplicate_decisions, %q(decision IN ('clear', 'likely', 'confirmed', 'false_positive', 'manual_exception')), name: "duplicate_decisions_decision"
    add_check_constraint :duplicate_decisions, %q(decision NOT IN ('false_positive', 'manual_exception') OR length(trim(coalesce(reason, ''))) > 0), name: "duplicate_override_reason"
    add_check_constraint :remote_snapshots, %q(kind IN ('draft', 'submission')), name: "remote_snapshots_kind"
    add_check_constraint :remote_snapshots, "local_revision >= 0", name: "remote_revision_nonnegative"
    add_check_constraint :ai_runs, %q(purpose IN ('assessment', 'prose')), name: "ai_runs_purpose"
    add_check_constraint :ai_runs, %q(status IN ('pending', 'running', 'succeeded', 'failed', 'unusable', 'stale')), name: "ai_runs_status"
    add_check_constraint :release_events, "sequence > 0 AND input_revision >= 0", name: "event_revisions_valid"
    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          CREATE TRIGGER payload_identity_no_update BEFORE UPDATE OF release_id, number, original_filename, format, sha256, size_bytes ON payload_revisions
          BEGIN SELECT RAISE(ABORT, 'Payload identity is immutable'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER provider_identity_no_update BEFORE UPDATE OF role, provider, identity_key, endpoint ON provider_connections
          BEGIN SELECT RAISE(ABORT, 'Provider identity is immutable'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER preparation_revisions_no_update BEFORE UPDATE ON preparation_revisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER preparation_revisions_no_delete BEFORE DELETE ON preparation_revisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER evidence_items_no_update BEFORE UPDATE ON evidence_items
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER evidence_items_no_delete BEFORE DELETE ON evidence_items
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER reviewed_facts_no_update BEFORE UPDATE ON reviewed_facts
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER reviewed_facts_no_delete BEFORE DELETE ON reviewed_facts
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER fact_evidence_links_no_update BEFORE UPDATE ON fact_evidence_links
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER fact_evidence_links_no_delete BEFORE DELETE ON fact_evidence_links
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER findings_no_update BEFORE UPDATE ON findings
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER findings_no_delete BEFORE DELETE ON findings
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER finding_acknowledgements_no_update BEFORE UPDATE ON finding_acknowledgements
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER finding_acknowledgements_no_delete BEFORE DELETE ON finding_acknowledgements
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER cover_revisions_no_update BEFORE UPDATE ON cover_revisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER cover_revisions_no_delete BEFORE DELETE ON cover_revisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER cover_hostings_no_update BEFORE UPDATE ON cover_hostings
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER cover_hostings_no_delete BEFORE DELETE ON cover_hostings
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER content_revisions_no_update BEFORE UPDATE ON content_revisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER content_revisions_no_delete BEFORE DELETE ON content_revisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER duplicate_checks_no_update BEFORE UPDATE ON duplicate_checks
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER duplicate_checks_no_delete BEFORE DELETE ON duplicate_checks
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER duplicate_decisions_no_update BEFORE UPDATE ON duplicate_decisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER duplicate_decisions_no_delete BEFORE DELETE ON duplicate_decisions
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER remote_snapshots_no_update BEFORE UPDATE ON remote_snapshots
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER remote_snapshots_no_delete BEFORE DELETE ON remote_snapshots
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER release_events_no_update BEFORE UPDATE ON release_events
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
        execute <<~SQL.squish
          CREATE TRIGGER release_events_no_delete BEFORE DELETE ON release_events
          BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
        SQL
      end
    end
  end
end
