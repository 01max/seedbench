# Integration validation

Discovery performed on 2026-11-07. C411 category and draft reads have been
verified. Publication, other provider credentials, and seeding remain unverified.

## Connection inventory

| Provider | Observed configuration | Verification still needed |
| --- | --- | --- |
| C411 | The production API key is configured as `C411_API_KEY` in the ignored `.env`. Category listing, book options, draft listing, and an existing draft read returned HTTP 200. | Draft mutations remain to be checked. Profile access returned HTTP 403; API account identity could not be independently confirmed through that endpoint. Publication is forbidden by the operator. |
| Deluge | The `george-basics` Windmill workspace contains a secret variable and an existing torrent-inbox script referencing it. | Verify authentication and daemon identity with a bounded diagnostic before testing torrent operations. |
| OpenAI | The same workspace contains an OpenAI resource and a secret-variable reference. | Establish whether the code-generation connection is intended for Seedbench, and verify the selected model and structured output using synthetic evidence. |
| Postimages | The upload helper's local key file exists with owner-only `0600` permissions. | Verify upload and direct-image retrieval with an identified test image. File presence does not prove a valid key. |

No credential values were printed or added to tracked files. The private
inventory records actual connection references outside version control. The
local `.env` permissions were tightened to `0600`; private responses use `0600`
files under a `0700` directory. The entire `tmp/` directory is ignored.

The authenticated C411 documentation is available at
[the integration guide](https://c411.org/user/integrations/guide). Its API
contracts and current ebook rules have not yet been fully reviewed or exercised.
The draft listing reported six existing drafts and a maximum of 15. Those drafts
are outside the mutation test scope.

## Existing automation and candidate paths

Read-only inspection of the deployed Windmill torrent-inbox script found:

- A Deluge web connection and JSON-RPC authentication using its secret variable.
- Candidate Deluge payload directory `/data/completed/uploads`.
- A Windmill torrent inbox at `/data/torrent-inbox`, with a `c411_uploads`
  subdirectory that the automation may import, recheck, and resume.
- A diagnostic option that avoids the normal inbox-processing branch. Its
  client initialization can connect the web UI to a daemon if disconnected;
  inspect connection state before relying on it as a strictly read-only probe.

These are configuration observations, not verified host/container mount
mappings. No app mount, same-filesystem staging directory, daemon UID/GID,
LAN/Tailscale binding, or shared payload hash has been verified. Keep disposable
probe artifacts outside the watched inbox until their import is intended.

## Test-data boundary

The operator supplied nine ebooks in `tmp/ebooks`: seven EPUBs, one PDF, and one
MOBI. Their paths, sizes, SHA-256 hashes, and available embedded metadata
candidates are recorded in the private inventory. Original bytes and filenames
remain unchanged. Metadata candidates have not been certified as edition facts.

The operator authorized inspection and draft tests with these files and
explicitly prohibited publication because this is a production API key. Use
only a newly created, clearly identified test draft for mutation tests. Existing
browser uploads, drafts, published submissions, and torrents are outside that
mutation scope. No publication, image upload, torrent import, or seeding
operation was performed during discovery.

Record the selected draft's identity and any remote identifiers in the private
inventory before subsequent changes. Use synthetic evidence for the AI check
and a disposable image for the image-host check. Do not call the publication
endpoint or start distribution. Successful draft operations cannot validate
publication or personalized torrent retrieval.

## Remaining prerequisites

- Create an isolated test draft within the recorded authorization boundary.
- Resolve which OpenAI connection Seedbench should use.
- Read current authenticated API, ebook, naming, description/NFO, image, and
  publication rules before encoding provider behavior.
- Exercise draft lifecycle, concurrency and failures only against the identified
  test draft; record actual requests and responses with secrets redacted.
- Publication, personalized torrent retrieval, and post-publication behavior
  cannot be tested under the current authorization. Keep them unverified.
- Verify George's host/app/Deluge path identity and access with synthetic bytes.
- Verify paused import, per-torrent options, full recheck, resume, and bounded
  tracker acceptance against the identified test torrent.
- Verify Postimages, structured output, and Linux inspection/OCR/torrent tools.

The checkout has an `origin` remote, and its main branch matches the initial
local commit. There is no Rails application, spec runner, or linter yet;
application verification cannot run at this stage.
