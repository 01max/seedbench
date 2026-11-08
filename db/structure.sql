CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "fact_evidence_links" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "reviewed_fact_id" bigint NOT NULL, "evidence_item_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_390002d659"
FOREIGN KEY ("release_id", "reviewed_fact_id")
  REFERENCES "reviewed_facts" ("release_id", "id")
, CONSTRAINT "fk_rails_76759d02ae"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_5b8bf72e8e"
FOREIGN KEY ("release_id", "evidence_item_id")
  REFERENCES "evidence_items" ("release_id", "id")
);
CREATE INDEX "index_fact_evidence_links_on_release_id" ON "fact_evidence_links" ("release_id");
CREATE UNIQUE INDEX "index_fact_evidence_links_on_release_id_and_id" ON "fact_evidence_links" ("release_id", "id");
CREATE UNIQUE INDEX "idx_on_reviewed_fact_id_evidence_item_id_4b9b4ea960" ON "fact_evidence_links" ("reviewed_fact_id", "evidence_item_id");
CREATE TABLE IF NOT EXISTS "finding_acknowledgements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "finding_id" bigint NOT NULL, "acknowledged" boolean NOT NULL, "actor" varchar NOT NULL, "note" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_e13fc9786b"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_dffc13ec6a"
FOREIGN KEY ("release_id", "finding_id")
  REFERENCES "findings" ("release_id", "id")
);
CREATE INDEX "index_finding_acknowledgements_on_release_id" ON "finding_acknowledgements" ("release_id");
CREATE UNIQUE INDEX "index_finding_acknowledgements_on_release_id_and_id" ON "finding_acknowledgements" ("release_id", "id");
CREATE TABLE IF NOT EXISTS "releases" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar, "author" varchar, "proposed_name" varchar, "automatic_ai" boolean DEFAULT TRUE NOT NULL, "input_revision" integer DEFAULT 0 NOT NULL, "lock_version" integer DEFAULT 0 NOT NULL, "inspection_state" varchar DEFAULT 'pending' NOT NULL, "preparation_state" varchar DEFAULT 'unprepared' NOT NULL, "draft_state" varchar DEFAULT 'unlinked' NOT NULL, "publication_state" varchar DEFAULT 'unpublished' NOT NULL, "seeding_state" varchar DEFAULT 'not_started' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT releases_inspection_state CHECK (inspection_state IN ('pending', 'running', 'succeeded', 'failed')), CONSTRAINT releases_preparation_state CHECK (preparation_state IN ('unprepared', 'running', 'prepared', 'stale', 'failed')), CONSTRAINT releases_draft_state CHECK (draft_state IN ('unlinked', 'synced', 'conflicted', 'missing')), CONSTRAINT releases_publication_state CHECK (publication_state IN ('unpublished', 'submitting', 'published', 'outcome_unknown', 'failed')), CONSTRAINT releases_seeding_state CHECK (seeding_state IN ('not_started', 'checking', 'seeding', 'succeeded', 'failed', 'unknown')), CONSTRAINT release_revisions_nonnegative CHECK (input_revision >= 0 AND lock_version >= 0));
CREATE TABLE IF NOT EXISTS "provider_connections" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "role" varchar NOT NULL, "provider" varchar NOT NULL, "identity_key" varchar NOT NULL, "label" varchar NOT NULL, "endpoint" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT provider_role_matches CHECK ((role = 'publishing' AND provider = 'c411') OR (role = 'torrent_client' AND provider = 'deluge') OR (role = 'ai' AND provider = 'openai') OR (role = 'image_host' AND provider = 'postimages')));
CREATE UNIQUE INDEX "index_provider_connections_on_role_and_identity_key" ON "provider_connections" ("role", "identity_key");
CREATE UNIQUE INDEX "index_provider_connections_on_role_and_id" ON "provider_connections" ("role", "id");
CREATE TABLE IF NOT EXISTS "provider_assignments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "role" varchar NOT NULL, "provider_connection_id" bigint, "assigned_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_df6fb68168"
FOREIGN KEY ("role", "provider_connection_id")
  REFERENCES "provider_connections" ("role", "id")
, CONSTRAINT "fk_rails_265c8d18a5"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT provider_assignments_role CHECK (role IN ('publishing', 'torrent_client', 'ai', 'image_host')));
CREATE INDEX "index_provider_assignments_on_release_id" ON "provider_assignments" ("release_id");
CREATE UNIQUE INDEX "index_provider_assignments_on_release_id_and_id" ON "provider_assignments" ("release_id", "id");
CREATE UNIQUE INDEX "index_provider_assignments_on_release_id_and_role" ON "provider_assignments" ("release_id", "role");
CREATE TABLE IF NOT EXISTS "evidence_items" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "payload_revision_id" bigint NOT NULL, "evidence_key" varchar NOT NULL, "kind" varchar NOT NULL, "source" varchar NOT NULL, "captured_at" datetime(6) NOT NULL, "input_revision" integer NOT NULL, "data" json DEFAULT '{}' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d45c4a6c5a"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_29f12d7e58"
FOREIGN KEY ("release_id", "payload_revision_id")
  REFERENCES "payload_revisions" ("release_id", "id")
, CONSTRAINT evidence_items_input_nonnegative CHECK (input_revision >= 0), CONSTRAINT evidence_items_data_object CHECK (json_valid(data) AND json_type(data) = 'object'));
CREATE INDEX "index_evidence_items_on_release_id" ON "evidence_items" ("release_id");
CREATE UNIQUE INDEX "index_evidence_items_on_release_id_and_id" ON "evidence_items" ("release_id", "id");
CREATE UNIQUE INDEX "index_evidence_items_on_release_id_and_evidence_key" ON "evidence_items" ("release_id", "evidence_key");
CREATE TABLE IF NOT EXISTS "reviewed_facts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "payload_revision_id" bigint NOT NULL, "field" varchar NOT NULL, "number" integer NOT NULL, "value" json NOT NULL, "actor" varchar NOT NULL, "reviewed_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_32e4a2025f"
FOREIGN KEY ("release_id", "payload_revision_id")
  REFERENCES "payload_revisions" ("release_id", "id")
, CONSTRAINT "fk_rails_70f103b35d"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT reviewed_facts_number_positive CHECK (number > 0));
CREATE INDEX "index_reviewed_facts_on_release_id" ON "reviewed_facts" ("release_id");
CREATE UNIQUE INDEX "index_reviewed_facts_on_release_id_and_id" ON "reviewed_facts" ("release_id", "id");
CREATE UNIQUE INDEX "index_reviewed_facts_on_release_id_and_field_and_number" ON "reviewed_facts" ("release_id", "field", "number");
CREATE TABLE IF NOT EXISTS "duplicate_checks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "input_revision" integer NOT NULL, "query" json DEFAULT '{}' NOT NULL, "candidates" json DEFAULT '[]' NOT NULL, "searched_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_45c965a2e3"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT duplicate_checks_input_nonnegative CHECK (input_revision >= 0), CONSTRAINT duplicate_checks_query_object CHECK (json_valid(query) AND json_type(query) = 'object'), CONSTRAINT duplicate_checks_candidates_array CHECK (json_valid(candidates) AND json_type(candidates) = 'array'));
CREATE INDEX "index_duplicate_checks_on_release_id" ON "duplicate_checks" ("release_id");
CREATE UNIQUE INDEX "index_duplicate_checks_on_release_id_and_id" ON "duplicate_checks" ("release_id", "id");
CREATE TABLE IF NOT EXISTS "payload_revisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "number" integer NOT NULL, "original_filename" varchar NOT NULL, "format" varchar NOT NULL, "size_bytes" bigint NOT NULL, "sha256" varchar NOT NULL, "locator" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_6422123307"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT payload_revisions_number_positive CHECK (number > 0), CONSTRAINT payload_revisions_format CHECK (format IN ('epub', 'pdf', 'mobi')), CONSTRAINT payload_identity_valid CHECK (size_bytes > 0 AND length(sha256) = 64 AND sha256 NOT GLOB '*[^0-9a-f]*'), CONSTRAINT payload_locator_relative CHECK (length(locator) > 0 AND substr(locator, 1, 1) != '/'));
CREATE INDEX "index_payload_revisions_on_release_id" ON "payload_revisions" ("release_id");
CREATE UNIQUE INDEX "index_payload_revisions_on_release_id_and_id" ON "payload_revisions" ("release_id", "id");
CREATE UNIQUE INDEX "payload_identity_key" ON "payload_revisions" ("release_id", "id", "sha256", "size_bytes");
CREATE UNIQUE INDEX "index_payload_revisions_on_release_id_and_number" ON "payload_revisions" ("release_id", "number");
CREATE TABLE IF NOT EXISTS "preparation_revisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "number" integer NOT NULL, "payload_revision_id" bigint NOT NULL, "release_name" varchar NOT NULL, "payload_name" varchar NOT NULL, "torrent_locator" varchar NOT NULL, "torrent_info_hash" varchar NOT NULL, "payload_sha256" varchar NOT NULL, "payload_size_bytes" bigint NOT NULL, "policy_version" varchar NOT NULL, "prepared_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_e26327841f"
FOREIGN KEY ("release_id", "payload_revision_id", "payload_sha256", "payload_size_bytes")
  REFERENCES "payload_revisions" ("release_id", "id", "sha256", "size_bytes")
, CONSTRAINT "fk_rails_11ef8a700a"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_4270fc48eb"
FOREIGN KEY ("release_id", "payload_revision_id")
  REFERENCES "payload_revisions" ("release_id", "id")
, CONSTRAINT preparation_revisions_number_positive CHECK (number > 0), CONSTRAINT preparation_identity_valid CHECK (payload_size_bytes > 0 AND length(payload_sha256) = 64 AND length(torrent_info_hash) = 40));
CREATE INDEX "index_preparation_revisions_on_release_id" ON "preparation_revisions" ("release_id");
CREATE UNIQUE INDEX "index_preparation_revisions_on_release_id_and_id" ON "preparation_revisions" ("release_id", "id");
CREATE UNIQUE INDEX "index_preparation_revisions_on_release_id_and_number" ON "preparation_revisions" ("release_id", "number");
CREATE TABLE IF NOT EXISTS "findings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "payload_revision_id" bigint NOT NULL, "code" varchar NOT NULL, "number" integer NOT NULL, "severity" varchar NOT NULL, "message" text NOT NULL, "input_revision" integer NOT NULL, "data" json DEFAULT '{}' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_ac3d33247b"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_00daf4dc01"
FOREIGN KEY ("release_id", "payload_revision_id")
  REFERENCES "payload_revisions" ("release_id", "id")
, CONSTRAINT findings_number_positive CHECK (number > 0), CONSTRAINT findings_input_nonnegative CHECK (input_revision >= 0), CONSTRAINT findings_data_object CHECK (json_valid(data) AND json_type(data) = 'object'), CONSTRAINT findings_severity CHECK (severity IN ('failure', 'uncertainty', 'info')));
CREATE INDEX "index_findings_on_release_id" ON "findings" ("release_id");
CREATE UNIQUE INDEX "index_findings_on_release_id_and_id" ON "findings" ("release_id", "id");
CREATE UNIQUE INDEX "index_findings_on_release_id_and_code_and_number" ON "findings" ("release_id", "code", "number");
CREATE TABLE IF NOT EXISTS "cover_revisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "payload_revision_id" bigint, "number" integer NOT NULL, "source_kind" varchar NOT NULL, "source_locator" varchar NOT NULL, "width" integer, "height" integer, "edition_evidence" json DEFAULT '{}' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_af8075ef54"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_fe5c17e5e0"
FOREIGN KEY ("release_id", "payload_revision_id")
  REFERENCES "payload_revisions" ("release_id", "id")
, CONSTRAINT cover_revisions_number_positive CHECK (number > 0), CONSTRAINT cover_revisions_edition_evidence_object CHECK (json_valid(edition_evidence) AND json_type(edition_evidence) = 'object'), CONSTRAINT cover_revisions_source_kind CHECK (source_kind IN ('embedded', 'remote', 'manual')), CONSTRAINT cover_dimensions_positive CHECK ((width IS NULL OR width > 0) AND (height IS NULL OR height > 0)));
CREATE INDEX "index_cover_revisions_on_release_id" ON "cover_revisions" ("release_id");
CREATE UNIQUE INDEX "index_cover_revisions_on_release_id_and_id" ON "cover_revisions" ("release_id", "id");
CREATE UNIQUE INDEX "index_cover_revisions_on_release_id_and_number" ON "cover_revisions" ("release_id", "number");
CREATE TABLE IF NOT EXISTS "cover_hostings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "cover_revision_id" bigint NOT NULL, "provider_connection_id" bigint NOT NULL, "provider_role" varchar DEFAULT 'image_host' NOT NULL, "direct_url" varchar NOT NULL, "media_type" varchar NOT NULL, "width" integer NOT NULL, "height" integer NOT NULL, "verified_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d3056cdfd1"
FOREIGN KEY ("release_id", "cover_revision_id")
  REFERENCES "cover_revisions" ("release_id", "id")
, CONSTRAINT "fk_rails_e45eb057f8"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_cee03d730c"
FOREIGN KEY ("provider_role", "provider_connection_id")
  REFERENCES "provider_connections" ("role", "id")
, CONSTRAINT cover_hostings_provider_role CHECK (provider_role = 'image_host'), CONSTRAINT hosted_dimensions_positive CHECK (width > 0 AND height > 0));
CREATE INDEX "index_cover_hostings_on_release_id" ON "cover_hostings" ("release_id");
CREATE UNIQUE INDEX "index_cover_hostings_on_release_id_and_id" ON "cover_hostings" ("release_id", "id");
CREATE TABLE IF NOT EXISTS "content_revisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "payload_revision_id" bigint, "preparation_revision_id" bigint, "cover_revision_id" bigint, "kind" varchar NOT NULL, "number" integer NOT NULL, "body" text NOT NULL, "origin" varchar NOT NULL, "input_revision" integer NOT NULL, "dependencies" json DEFAULT '{}' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_99da1382fa"
FOREIGN KEY ("release_id", "cover_revision_id")
  REFERENCES "cover_revisions" ("release_id", "id")
, CONSTRAINT "fk_rails_94be3235f3"
FOREIGN KEY ("release_id", "payload_revision_id")
  REFERENCES "payload_revisions" ("release_id", "id")
, CONSTRAINT "fk_rails_8bc3e9f3f9"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_5093099352"
FOREIGN KEY ("release_id", "preparation_revision_id")
  REFERENCES "preparation_revisions" ("release_id", "id")
, CONSTRAINT content_revisions_number_positive CHECK (number > 0), CONSTRAINT content_revisions_input_nonnegative CHECK (input_revision >= 0), CONSTRAINT content_revisions_dependencies_object CHECK (json_valid(dependencies) AND json_type(dependencies) = 'object'), CONSTRAINT content_revisions_kind CHECK (kind IN ('bbcode', 'nfo', 'presentation', 'notes')), CONSTRAINT content_revisions_origin CHECK (origin IN ('human', 'generated', 'ai')));
CREATE INDEX "index_content_revisions_on_release_id" ON "content_revisions" ("release_id");
CREATE UNIQUE INDEX "index_content_revisions_on_release_id_and_id" ON "content_revisions" ("release_id", "id");
CREATE UNIQUE INDEX "index_content_revisions_on_release_id_and_kind_and_number" ON "content_revisions" ("release_id", "kind", "number");
CREATE TABLE IF NOT EXISTS "duplicate_decisions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "duplicate_check_id" bigint NOT NULL, "candidate_key" varchar NOT NULL, "decision" varchar NOT NULL, "reason" text, "actor" varchar NOT NULL, "reviewed_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_95ac167203"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_74cd7c854b"
FOREIGN KEY ("release_id", "duplicate_check_id")
  REFERENCES "duplicate_checks" ("release_id", "id")
, CONSTRAINT duplicate_decisions_decision CHECK (decision IN ('clear', 'likely', 'confirmed', 'false_positive', 'manual_exception')), CONSTRAINT duplicate_override_reason CHECK (decision NOT IN ('false_positive', 'manual_exception') OR length(trim(coalesce(reason, ''))) > 0));
CREATE INDEX "index_duplicate_decisions_on_release_id" ON "duplicate_decisions" ("release_id");
CREATE UNIQUE INDEX "index_duplicate_decisions_on_release_id_and_id" ON "duplicate_decisions" ("release_id", "id");
CREATE UNIQUE INDEX "idx_on_duplicate_check_id_candidate_key_eadb0be4da" ON "duplicate_decisions" ("duplicate_check_id", "candidate_key");
CREATE TABLE IF NOT EXISTS "remote_snapshots" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "provider_connection_id" bigint NOT NULL, "provider_role" varchar DEFAULT 'publishing' NOT NULL, "kind" varchar NOT NULL, "remote_id" varchar NOT NULL, "remote_revision" varchar, "local_revision" integer NOT NULL, "base_content" json DEFAULT '{}' NOT NULL, "remote_content" json DEFAULT '{}' NOT NULL, "remote_deleted" boolean DEFAULT FALSE NOT NULL, "observed_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_426059e9ee"
FOREIGN KEY ("provider_role", "provider_connection_id")
  REFERENCES "provider_connections" ("role", "id")
, CONSTRAINT "fk_rails_030e5c7f4c"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT remote_snapshots_provider_role CHECK (provider_role = 'publishing'), CONSTRAINT remote_snapshots_base_content_object CHECK (json_valid(base_content) AND json_type(base_content) = 'object'), CONSTRAINT remote_snapshots_remote_content_object CHECK (json_valid(remote_content) AND json_type(remote_content) = 'object'), CONSTRAINT remote_snapshots_kind CHECK (kind IN ('draft', 'submission')), CONSTRAINT remote_revision_nonnegative CHECK (local_revision >= 0));
CREATE INDEX "index_remote_snapshots_on_release_id" ON "remote_snapshots" ("release_id");
CREATE UNIQUE INDEX "index_remote_snapshots_on_release_id_and_id" ON "remote_snapshots" ("release_id", "id");
CREATE TABLE IF NOT EXISTS "ai_runs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "provider_connection_id" bigint NOT NULL, "provider_role" varchar DEFAULT 'ai' NOT NULL, "input_revision" integer NOT NULL, "purpose" varchar NOT NULL, "prompt_version" varchar NOT NULL, "model" varchar NOT NULL, "evidence_keys" json DEFAULT '[]' NOT NULL, "status" varchar DEFAULT 'pending' NOT NULL, "result" json, "error_code" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9ce3a73ba1"
FOREIGN KEY ("provider_role", "provider_connection_id")
  REFERENCES "provider_connections" ("role", "id")
, CONSTRAINT "fk_rails_869165a4b6"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT ai_runs_provider_role CHECK (provider_role = 'ai'), CONSTRAINT ai_runs_input_nonnegative CHECK (input_revision >= 0), CONSTRAINT ai_runs_evidence_keys_array CHECK (json_valid(evidence_keys) AND json_type(evidence_keys) = 'array'), CONSTRAINT ai_runs_purpose CHECK (purpose IN ('assessment', 'prose')), CONSTRAINT ai_runs_status CHECK (status IN ('pending', 'running', 'succeeded', 'failed', 'unusable', 'stale')));
CREATE INDEX "index_ai_runs_on_release_id" ON "ai_runs" ("release_id");
CREATE UNIQUE INDEX "index_ai_runs_on_release_id_and_id" ON "ai_runs" ("release_id", "id");
CREATE TABLE IF NOT EXISTS "release_events" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "sequence" integer NOT NULL, "name" varchar NOT NULL, "actor" varchar NOT NULL, "input_revision" integer NOT NULL, "data" json DEFAULT '{}' NOT NULL, "occurred_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_fbf078e78f"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT release_events_input_nonnegative CHECK (input_revision >= 0), CONSTRAINT release_events_data_object CHECK (json_valid(data) AND json_type(data) = 'object'), CONSTRAINT event_revisions_valid CHECK (sequence > 0 AND input_revision >= 0));
CREATE INDEX "index_release_events_on_release_id" ON "release_events" ("release_id");
CREATE UNIQUE INDEX "index_release_events_on_release_id_and_id" ON "release_events" ("release_id", "id");
CREATE UNIQUE INDEX "index_release_events_on_release_id_and_sequence" ON "release_events" ("release_id", "sequence");
CREATE TRIGGER payload_identity_no_update BEFORE UPDATE OF release_id, number, original_filename, format, sha256, size_bytes ON payload_revisions
BEGIN SELECT RAISE(ABORT, 'Payload identity is immutable'); END;
CREATE TRIGGER provider_identity_no_update BEFORE UPDATE OF role, provider, identity_key, endpoint ON provider_connections
BEGIN SELECT RAISE(ABORT, 'Provider identity is immutable'); END;
CREATE TRIGGER preparation_revisions_no_update BEFORE UPDATE ON preparation_revisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER preparation_revisions_no_delete BEFORE DELETE ON preparation_revisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER evidence_items_no_update BEFORE UPDATE ON evidence_items
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER evidence_items_no_delete BEFORE DELETE ON evidence_items
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER reviewed_facts_no_update BEFORE UPDATE ON reviewed_facts
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER reviewed_facts_no_delete BEFORE DELETE ON reviewed_facts
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER fact_evidence_links_no_update BEFORE UPDATE ON fact_evidence_links
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER fact_evidence_links_no_delete BEFORE DELETE ON fact_evidence_links
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER findings_no_update BEFORE UPDATE ON findings
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER findings_no_delete BEFORE DELETE ON findings
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER finding_acknowledgements_no_update BEFORE UPDATE ON finding_acknowledgements
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER finding_acknowledgements_no_delete BEFORE DELETE ON finding_acknowledgements
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER cover_revisions_no_update BEFORE UPDATE ON cover_revisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER cover_revisions_no_delete BEFORE DELETE ON cover_revisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER cover_hostings_no_update BEFORE UPDATE ON cover_hostings
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER cover_hostings_no_delete BEFORE DELETE ON cover_hostings
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER content_revisions_no_update BEFORE UPDATE ON content_revisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER content_revisions_no_delete BEFORE DELETE ON content_revisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER duplicate_checks_no_update BEFORE UPDATE ON duplicate_checks
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER duplicate_checks_no_delete BEFORE DELETE ON duplicate_checks
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER duplicate_decisions_no_update BEFORE UPDATE ON duplicate_decisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER duplicate_decisions_no_delete BEFORE DELETE ON duplicate_decisions
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER remote_snapshots_no_update BEFORE UPDATE ON remote_snapshots
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER remote_snapshots_no_delete BEFORE DELETE ON remote_snapshots
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER release_events_no_update BEFORE UPDATE ON release_events
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TRIGGER release_events_no_delete BEFORE DELETE ON release_events
BEGIN SELECT RAISE(ABORT, 'Revision history is append-only'); END;
CREATE TABLE IF NOT EXISTS "workflow_operations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "kind" varchar NOT NULL, "request_key" varchar NOT NULL, "effect" varchar NOT NULL, "state" varchar DEFAULT 'pending' NOT NULL, "phase" varchar DEFAULT 'requested' NOT NULL, "input_revision" integer NOT NULL, "attempts" integer DEFAULT 0 NOT NULL, "parameters" json DEFAULT '{}' NOT NULL, "result" json DEFAULT '{}' NOT NULL, "external_reference" json DEFAULT '{}' NOT NULL, "attempt_token" varchar, "lease_expires_at" datetime(6), "started_at" datetime(6), "finished_at" datetime(6), "error_code" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_072857f718"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT operation_revisions_valid CHECK (input_revision >= 0 AND attempts >= 0), CONSTRAINT operation_request_key_valid CHECK (length(request_key) BETWEEN 1 AND 80), CONSTRAINT operation_effect_valid CHECK (effect IN ('local', 'remote', 'filesystem')), CONSTRAINT operation_state_valid CHECK (state IN ('pending', 'running', 'succeeded', 'failed', 'stale', 'outcome_unknown')), CONSTRAINT running_operation_has_attempt CHECK (state != 'running' OR (attempt_token IS NOT NULL AND lease_expires_at IS NOT NULL)), CONSTRAINT operation_parameters_object CHECK (json_valid(parameters) AND json_type(parameters) = 'object'), CONSTRAINT operation_result_object CHECK (json_valid(result) AND json_type(result) = 'object'), CONSTRAINT operation_external_reference_object CHECK (json_valid(external_reference) AND json_type(external_reference) = 'object'));
CREATE INDEX "index_workflow_operations_on_release_id" ON "workflow_operations" ("release_id");
CREATE UNIQUE INDEX "index_workflow_operations_on_release_id_and_request_key" ON "workflow_operations" ("release_id", "request_key");
CREATE UNIQUE INDEX "index_workflow_operations_on_release_id_and_id" ON "workflow_operations" ("release_id", "id");
CREATE INDEX "index_workflow_operations_on_state_and_lease_expires_at" ON "workflow_operations" ("state", "lease_expires_at");
CREATE TABLE IF NOT EXISTS "dispatch_intents" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "release_id" integer NOT NULL, "workflow_operation_id" bigint NOT NULL, "state" varchar DEFAULT 'pending' NOT NULL, "attempts" integer DEFAULT 0 NOT NULL, "dispatch_token" varchar, "claimed_until" datetime(6), "dispatched_at" datetime(6), "job_id" varchar, "error_code" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_8bde797c9d"
FOREIGN KEY ("release_id")
  REFERENCES "releases" ("id")
, CONSTRAINT "fk_rails_fe6b47e832"
FOREIGN KEY ("release_id", "workflow_operation_id")
  REFERENCES "workflow_operations" ("release_id", "id")
, CONSTRAINT dispatch_state_valid CHECK (state IN ('pending', 'dispatching', 'dispatched') AND attempts >= 0), CONSTRAINT dispatch_claim_valid CHECK (state != 'dispatching' OR (dispatch_token IS NOT NULL AND claimed_until IS NOT NULL)));
CREATE INDEX "index_dispatch_intents_on_release_id" ON "dispatch_intents" ("release_id");
CREATE UNIQUE INDEX "index_dispatch_intents_on_workflow_operation_id" ON "dispatch_intents" ("workflow_operation_id");
CREATE INDEX "index_dispatch_intents_on_state_and_claimed_until" ON "dispatch_intents" ("state", "claimed_until");
INSERT INTO "schema_migrations" (version) VALUES
('20261108143000'),
('20261108140000');

