# Optional evidence assessment and French prose

Open **Assistance** to request an assessment or a presentation, inspect the
returned suggestions, and compare them with the saved text. All metadata and
release text remain editable by hand. An unavailable provider or unusable result
never completes or blocks the mechanical publication prerequisites by itself.

## Configure and request

Create an OpenAI connection in **Réglages**, choose its model, and deliberately
assign that connection to the release. Credentials remain encrypted in local
state. Changing defaults affects future uploads; existing releases keep their
assigned identity. Runtime credentials are configured through Settings, not an
implicit import from a local `.env` file.

**Premier passage automatique** is recorded when a release is created. If it
was enabled and the assigned connection is configured, successful inspection
queues one assessment and one prose request for that payload. Disabling the
global option affects future uploads. It does not launch or cancel requests for
existing releases. Explicit requests remain available with automatic assistance
disabled. A pending/running request prevents another request of the same type.

The worker sends requests outside its application write transactions. Each run
retains the requested model, returned model/usage when available, prompt version,
input revision, exact evidence snapshot, scope, source identifiers and result.
The selected model is sent unchanged; there is no automatic model fallback.

## What leaves the application

Routine requests contain a focused JSON pack, limited to 32 KiB: reviewed fact
context, bounded embedded metadata and measurements, opening/ending excerpts,
contents evidence when available, and up to two edition records. Each fragment
has a stable identifier, source and provenance and is limited to 1,800 bytes.
Truncation and omitted evidence are recorded. No ebook file or cover is uploaded
to OpenAI. PDF/OCR and MOBI excerpts use the retained inspection samples; EPUB
navigation/NCX contents are retained separately from the spine.

**Analyse ciblée** requires one to eight explicitly selected retained fragments
and a 20–500 character scope note. This can include additional inspection or
edition evidence omitted from the routine pack. It does not fetch new pages or
turn into an unrestricted whole-book inspection. Examine missing passages
directly when the retained samples are insufficient.

The request uses separate developer instructions and a lower-priority user
message containing only the evidence pack. No tools, browsing, file attachment,
conversation continuation or remote action capability is supplied. Responses
are requested with `store: false`; the provider account's data policies still
apply. Enabling/configuring assistance permits these selected excerpts to leave
the application; turn off the first pass before uploading if that is unwanted.

## Review suggestions

Assessment offers candidate edition values and uncertain observations with
citations. Its schema excludes technical fields, completeness certification and
action decisions. Candidate values must occur in cited evidence. Check the
source and edition before **Adopter cette valeur après revue**; adoption records
a human-reviewed fact and links it to the run and quoted evidence. An ISBN still
passes the ordinary checksum and edition-review rules.

Prose generation offers original French **Présentation** and optional **Notes**.
It cannot generate the BBCode skeleton, NFO, filenames, ISBN or cover URL. Review
the saved/proposed comparison, then accept one field at a time. Acceptance
changes only that field and appends its AI provenance. It does not replace the
saved BBCode/NFO. **Proposer le BBCode avec la prose retenue** creates a separate
code-generated replacement for explicit acceptance.

Changing the relevant evidence/facts or editing the target field makes an old
suggestion inapplicable. A late result remains visible, with its original inputs,
and cannot overwrite newer text. An unrelated NFO edit is preserved even if the
operator subsequently accepts still-applicable presentation prose. Dirty browser
edits are saved before any request or acceptance; a conflict keeps them visible.

Structured output validation checks exact fields/types, supplied evidence IDs,
source support for candidate values, length limits and permitted plain text.
Refusals, incomplete/malformed responses, unsupported fields/citations and unsafe
markup are unusable. These checks do not certify factual truth, literary quality
or French fluency; human review remains necessary. AI observations do not clear
measured failures, acknowledge warnings or make a publication decision.

## Failure and persistence

A transport failure records a sanitized code without storing raw provider error
bodies or credentials. An interrupted generation is not automatically sent again:
its retry records an unusable outcome and the operator can explicitly rerun.
Unstarted requests made stale by edits are cancelled before making a provider
call. Terminal run results and request provenance have database history guards.

The runtime checks retain a focused request, citations and an unaccepted
suggestion through container recreation while preserving the original human
text. Isolated tests exercise a fully manual inspection/content/preparation/
cover/duplicate review path with assistance disabled and with provider failures.
Draft and Publish remain disabled in this development preview.

The 2026-11-10 live adapter check used two small synthetic fragments and
`gpt-4.1-mini-2025-04-14`: both assessment and prose outputs passed application
validation. No operator ebook contents were sent. Automated tests use isolated
HTTP fixtures and never read live provider credentials.

API references: [Responses structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses)
and [Responses request and storage configuration](https://developers.openai.com/api/docs/guides/migrate-to-responses?api-mode=responses).
