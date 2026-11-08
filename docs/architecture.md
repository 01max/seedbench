# Application boundaries

Seedbench is one Rails application. Web, worker, and CLI entry points share
application services and persistence. English identifiers and French interface
text keep code conventions distinct from operator presentation.

| Layer | Owns | Delegates |
| --- | --- | --- |
| Controllers | Authentication, permitted input, service calls, expected-error translation, HTML/Turbo responses | Decisions, transactions, provider transport, filesystem changes |
| Jobs | Serialized identifiers, scheduling, bounded retries, service calls | Workflow decisions and state transitions |
| Models | Associations, declarative validation, enums, encryption/password declarations, simple scopes | Business callbacks, external I/O, workflow methods, enqueueing |
| Services | Use cases, transactions, locking, revision checks, idempotency, state transitions, event recording | HTTP/session response concerns and provider wire formats |
| Policies and queries | Eligibility reasons, naming/content policy, derived checks, focused database reads | Rendering and transport |
| Provider adapters | Authentication, serialization, provider errors and protocol translation | Local workflow state and eligibility |

## Interfaces and namespaces

Services are plain Ruby classes with `.call` and explicit keyword inputs.
Queries return useful data. Commands return the persisted record or a small
operation summary. A service hides a coherent operation; a trivial persistence
call does not automatically need its own service. Services can be invoked from
HTTP, Active Job, or Rails runner without a controller or session.

Use `app/services` for orchestration, `app/policies` for decisions,
`app/queries` for focused reads, and `app/adapters/providers` for provider
transport. Namespaces follow the responsibility:

| Namespace | Responsibility |
| --- | --- |
| `Releases` | Intake, local edits, checklist acknowledgements and history |
| `Ebooks` | Inspection, evidence and edition review |
| `Preparation` | Naming, path validation, canonical moves and torrent verification |
| `Content` | BBCode/NFO assembly, validation and sanitized preview |
| `Covers`, `Duplicates`, `Ai` | Assistance and review workflows |
| `Drafts`, `Publication`, `Seeding` | Explicit remote operations and reconciliation |
| `Providers` | Publishing, torrent client, AI and image-host adapters; C411 policy |
| `Authentication`, `Settings` | Operator access and provider configuration |

These directories establish ownership for subsequent features. They do not
claim those workflows are implemented. No mandatory `BaseService`, generic
repository, or result/monad layer is required.

## Expected failures

Raise a named exception for a known failed precondition, with an actionable
message and structured readers for the details the caller needs. For example,
a payload mismatch error can expose expected and actual hashes; an unsafe-path
error can expose a sanitized relative locator. Callers rescue the specific
expected exception and translate it into form feedback or an operation failure.
Do not rescue `StandardError` merely to return false or hide unexpected defects.
No mandatory shared exception superclass is required.

Provider adapters translate transport failures into named provider errors.
Messages, structured details, logs, and persisted events must exclude credentials,
private torrent URLs, and unreviewed raw provider responses. Controllers and jobs
must not reconstruct domain decisions from exception strings.

## Transactions and background work

Keep SQLite write transactions short. Snapshot input revisions before hashing,
parsing, or provider calls, and commit results only if the inputs still apply.
Application and Solid Queue databases are separate transaction boundaries;
future workflow dispatch must persist intent and recover interrupted enqueueing.
A queue transaction cannot roll back an accepted remote operation or a renamed
file. Duplicate delivery and ambiguous outcomes require reconciliation.

Model declarations and database constraints protect persistence integrity.
Behavior tests and code review enforce ownership; an AST rule is not a substitute
for assessing whether a service has a coherent responsibility.
