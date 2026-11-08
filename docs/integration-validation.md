# Integration validation

Discovery performed on 2026-11-07. C411 category reads and an isolated draft
lifecycle have been verified. Synthetic Postimages/OpenAI checks and Linux
tooling checks are recorded in [provider and tooling observations](provider-tooling.md).
The [isolated Deluge protocol check](deluge-protocol.md) passed on 2026-11-08.
Publication and production seeding remain unverified. See [the API observations](c411-api.md)
for measured responses, concurrency limitations, and unresolved policy checks.

## Connection inventory

| Provider | Observed configuration | Verification still needed |
| --- | --- | --- |
| C411 | The production API key is configured as `C411_API_KEY` in the ignored `.env`. Category/options reads and isolated draft create/read/update/delete succeeded. | Profile access returned HTTP 403; API account identity could not be independently confirmed through that endpoint. Publication is forbidden by the operator. |
| Deluge | An isolated Deluge 2.2.0 daemon passed paused import, per-torrent options, recheck, resume, seeding, and tracker acceptance/rejection checks. The `george-basics` Windmill workspace also contains a production connection reference. | Verify the selected deployment's daemon identity, authentication, permissions, and payload mapping before production client operations. |
| OpenAI | The same workspace contains an OpenAI resource and a secret-variable reference. A synthetic strict-schema request succeeded, and an invalid schema was rejected. | Make a deliberate application connection assignment; the probe does not select production defaults. |
| Postimages | The upload helper authenticated and returned a loadable direct PNG for a synthetic image. | Hosting reduced 600 × 900 to 512 × 768; actual cover quality and C411 host policy remain to be verified. |

No credential values were printed or added to tracked files. The private
inventory records actual connection references outside version control. The
local `.env` permissions were tightened to `0600`; private responses use `0600`
files under a `0700` directory. The entire `tmp/` directory is ignored.

The authenticated C411 documentation is available at
[the integration guide](https://c411.org/user/integrations/guide). The
[2026-11-08 ebook policy review](c411-ebook-policy.md) records current rules and
the remaining undocumented contracts. Publication has not been exercised.
The draft listing reported six existing drafts and a maximum of 15. Those drafts
are outside the mutation test scope.

## Existing deployment observations

Read-only inspection of the deployed Windmill torrent-inbox script found:

- A Deluge web connection and JSON-RPC authentication using its secret variable.
- Candidate Deluge payload directory `/data/completed/uploads`.
- A Windmill torrent inbox at `/data/torrent-inbox`, with a `c411_uploads`
  subdirectory that the automation may import, recheck, and resume.
- A diagnostic option that avoids the normal inbox-processing branch. Its
  client initialization can connect the web UI to a daemon if disconnected;
  inspect connection state before relying on it as a strictly read-only probe.

The worker's inbox mount was observed with a read-only probe, but its
`/data/completed/uploads` path is absent. This is a property of that worker's
mounts, not a required application layout. Keep disposable artifacts outside
the watched inbox until their import is intended.

The [storage contract](storage-configuration.md) declares host binds in Compose
and lets the app and client use independently configured container roots.
Portable mount validation does not need George access. Actual deployment
permissions, client access, and LAN/Tailscale bindings still require acceptance
on the selected deployment host.

## Test-data boundary

The operator supplied nine ebooks in `tmp/ebooks`: seven EPUBs, one PDF, and one
MOBI. Their paths, sizes, SHA-256 hashes, and available embedded metadata
candidates are recorded in the private inventory. Original bytes and filenames
remain unchanged. Metadata candidates have not been certified as edition facts.

The operator authorized inspection and draft tests with these files and
explicitly prohibited publication because this is a production API key. Use
only a newly created, clearly identified test draft for mutation tests. Existing
browser uploads, drafts, published submissions, and torrents are outside that
mutation scope. One isolated test draft was created, updated, and deleted; the
original six drafts were preserved. One generated checkerboard was uploaded to
Postimages for verification. No operator ebook cover was uploaded, and no
operator ebook was published, imported into Deluge, or seeded. The isolated
Deluge check imported and removed three synthetic torrents without external
network access or production connections.

Record the selected draft's identity and any remote identifiers in the private
inventory before subsequent changes. Use synthetic evidence for the AI check
and a disposable image for the image-host check. Do not call the publication
endpoint or start distribution. Successful draft operations cannot validate
publication or personalized torrent retrieval.

## Remaining prerequisites

- Verify attachment round trips and handle actual production slot-limit errors
  without filling the account's slots merely for a test.
- Make a deliberate OpenAI application connection assignment.
- Apply the dated ebook policy and resolve its remaining host, renderer, and
  publication-timing uncertainties before claiming those contracts work.
- Exercise draft lifecycle, concurrency and failures only against the identified
  test draft; record actual requests and responses with secrets redacted.
- Publication, personalized torrent retrieval, and post-publication behavior
  cannot be tested under the current authorization. Keep them unverified.
- The portable synthetic mount check passed. Validate the selected production
  host's actual app/Deluge mount identities and access during deployment.
- The isolated Deluge protocol check passed, including incomplete data and
  tracker rejection. Verify actual daemon access and real tracker acceptance
  separately during authorized deployment acceptance.
- Carry the measured provider limitations and selected Linux tools into the
  application image, with separate real-file, parser-bound, and hostile-input
  checks.

The checkout has an `origin` remote. There is no Rails application, spec runner,
or linter yet; application verification cannot run at this stage.
