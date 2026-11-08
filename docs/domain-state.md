# Durable release state

`Release` owns independent inspection, preparation, draft, publication, and
seeding dimensions. An input revision records changes to reviewed inputs;
Rails optimistic locking separately detects concurrent record writes. There is
no single workflow status combining every dimension.

| Records | Retained state |
| --- | --- |
| Payload/preparation revisions | Original file identity, current relative locator, prepared names, matching payload hash/size, torrent identity and policy version |
| Evidence, reviewed facts and links | Stable evidence keys, source/time, payload revision, human review and supporting evidence |
| Findings and acknowledgements | Versioned findings and separate reversible acknowledgement history |
| Content and cover revisions/hosting | Full human text, generation provenance, dependencies, selected edition and verified hosted image bound to its cover revision |
| Duplicate checks/decisions | Search inputs/results, input revision, candidate decision and required override reason |
| Remote snapshots and AI runs | Sync base and observed content, remote identities, model/prompt/evidence provenance and input revision |
| Provider connections/assignments | Stable role/account identity and explicit release assignment, including an unconfigured role |
| Release events | Ordered actor/time/revision history with append-only storage |

Foreign keys prevent dangling records and cross-release references. Composite
keys also enforce connection-role matching and bind a preparation to its exact
payload hash and size. Positive revision numbers, supported formats/states,
JSON object/array shapes, and required override reasons have database constraints.

Revision history rejects SQL updates and deletes. Payload bytes/original identity
and connection identity are immutable, while the payload's current relative
locator can change through preparation and a connection label can change without
retargeting its account. Provider credentials and connection management remain
outside this persistence layer.

The primary database uses `db/structure.sql` so SQLite triggers and composite
constraints survive schema loading and restoration. The separate queue database
retains its Ruby schema. SQLite's command-line tool is included in the image;
no host database tooling is required. These records store metadata and relative
locators, without reading, copying, renaming, or distributing ebook files.

Local commands use explicit services. `Releases::Create` creates four
unconfigured provider assignments and initial history atomically. `Releases::Revise`
currently edits title/author against an expected input revision; unchanged edits
are no-ops. `Releases::Transition` changes one allowed workflow dimension without
pretending to validate a later provider-specific action. Final publication gates
remain the publishing service's responsibility.

Each write and its ordered event share an application transaction. Stale input
revisions raise `Releases::RevisionConflict` with expected and actual revisions;
invalid transitions retain dimension/from/to details. Event metadata is bounded
JSON containing identifiers and sanitized outcomes, with secret fields and URLs
rejected. Human content and private provider payloads belong in their dedicated
revision records rather than being copied into audit metadata.

## Durable background dispatch

`Workflows::Start` binds an opaque request key to one operation, input revision,
and parameter snapshot. It writes the operation, its dispatch intent, and history
in the same application transaction. Identical retries reuse that identity;
reusing the key for different inputs raises an idempotency conflict.

Enqueueing is registered with `ActiveRecord.after_all_transactions_commit` by the
service, with no model callback. The dispatcher claims an intent in a short
application transaction, calls Active Job outside that transaction, then records
the queue receipt. Queue rejection leaves the intent pending. A periodic bounded
recovery job handles committed pending intents and expired dispatch claims.
Queueing twice around a lost receipt is safe because execution claims the
operation identity and commits local effects with completion history atomically.

Computation and I/O run outside the application write transaction; a handler's
apply step performs only local persistence inside it. Definitions are explicit,
code-owned compute/apply/effect entries. No provider or feature handler is assumed
implemented: unknown kinds fail closed. Verification supplies a synthetic handler
that creates evidence, with no provider calls. This is internal work delivery,
not a seeding monitor or a runtime plugin interface.
