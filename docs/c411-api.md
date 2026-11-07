# C411 API observations

Verified on 2026-11-07 using the configured production key. The operator permits
inspection and draft tests and explicitly forbids publication. These results do
not establish a working publication or seeding integration.

## Authentication and read access

Use HTTPS with `Authorization: Bearer <key>` and a descriptive application
User-Agent. Reject redirects rather than forwarding credentials elsewhere.

| Request | Observed outcome |
| --- | --- |
| `GET /api/categories` | HTTP 200; category `Ebook` has ID `2`, and its `Livres` subcategory has ID `14`. Resolve IDs dynamically. |
| `GET /api/categories/14/options` | HTTP 200; required format type `12` includes EPUB `190`, MOBI `192`, PDF `193`; required language type `13` includes French `197`. Optional types include genre `14` and literary style `29`. |
| `GET /api/user/drafts` | HTTP 200; envelope contains `success`, `data`, `count`, `maxAllowed`. Six existing drafts; maximum 15. |
| `GET /api/user/drafts/{id}` | HTTP 200; envelope contains `success` and the full draft in `data`. |
| `GET /api/user/profile` | HTTP 403. The guide requires the separate `profile:read` scope; profile access is not necessary for draft operations. |

The Python client's default User-Agent received Cloudflare HTTP 403 with error
1010 before reaching the draft API. A descriptive Seedbench User-Agent, already
used by the successful reads, returned HTTP 200. Do not classify every HTTP 403
as an invalid API key or log raw error bodies.

## Draft fields and attachments

The list returns `id`, `name`, `title`, `category`, `subcategory`,
`hasTorrentFile`, `hasNfoFile`, `createdAt`, and `updatedAt`.

The detail response additionally exposes `description`, `categoryId`,
`subcategoryId`, `options`, `tmdbData`, `musicData`, `rawgData`, `bookData`,
`mediainfo`, `identifiers`, `templateId`, `uploaderNote`, `ebookMetadata`,
`torrentFile`, `nfoFile`, `isAutosave`, and `tpdbData`.

Existing attachment objects have `name` and `data` fields. The authenticated
[integration guide](https://c411.org/user/integrations/guide) describes base64
file data in the JSON body. The isolated test omitted both attachments; they
were returned as `null`. Attachment round trips have not been tested.

The test created an incomplete draft with `name`, `title`, `description`,
`categoryId`, `subcategoryId`, `options`, and `isAutosave: false`. It used a
unique Seedbench test marker, a supplied ebook's filename-derived title, French
test prose explicitly prohibiting publication, and no invented edition facts.
Successful storage does not establish release eligibility.

## Verified mutation lifecycle

| Operation | Observed outcome |
| --- | --- |
| `POST /api/user/drafts` | HTTP 200; `success`, `message`, `data`, including the new identifier. |
| Read created draft | HTTP 200; test marker and title persisted. |
| `PATCH /api/user/drafts/{id}` with only `description` | HTTP 200; `success` and `message`. A subsequent read confirmed the changed description and preserved title. `updatedAt` changed. |
| Patch with an old `updatedAt`, invalid `If-Match`, and stale `If-Unmodified-Since` | HTTP 200; a read confirmed that the stale test description overwrote the newer one. |
| Patch with category and subcategory `-1` | HTTP 500. This is an observed server failure, not a documented validation response. |
| `DELETE /api/user/drafts/{id}` | HTTP 200; `success` and `message`. |
| Read deleted draft | HTTP 404. No recovery mechanism was established. |
| List after cleanup | Same six original draft identifiers; the isolated test draft was absent. |

Only the newly created test draft was changed. Its marker was checked before
cleanup. No existing user draft was modified or deleted. Raw evidence and the
test identifier are stored privately outside Git.

The slot-exhaustion error was not provoked: filling all remaining production
slots would interfere with the operator. Treat the observed `maxAllowed` as a
snapshot and handle the actual future failure response without assuming its
status or shape.

## Concurrency limitation

No ETag or Last-Modified validator was returned by the draft reads. The tested
stale timestamp and conditional headers did not prevent an overwrite. Refresh
immediately before a write and compare against the last synchronized content.
That comparison can detect an earlier remote edit, but another client may edit
between the refresh and the write. Do not claim an atomic remote compare-and-set
contract or infer one from `updatedAt` alone.

## Publication documentation and unverified contracts

The authenticated guide documents direct `POST /api/torrents` using multipart
form data. It lists required torrent (maximum 10 MB), NFO (maximum 3 MB), title
(3–200 characters), description (at least 20 characters), category, and
subcategory. Options are encoded as JSON. The standard description format uses
BBCode; raw HTML requires an additional permission.

No request was sent to that endpoint. Personalized torrent retrieval,
submission-state reads, post-publication draft behavior, publication-time
validation, and tracker acceptance remain unverified. The guide's profile
endpoint is account information, not submission-state evidence.

## Ebook content policy remains incomplete

The authenticated naming page rendered the standalone pattern
`Titre.Auteur.Langue.[Extension]-Team` and a series/volume variant, with dotted
words, preserved source-team attribution, and `-NOTAG` for an unknown team. It
also distinguishes listing titles from original filenames for reposts.

The description/NFO page rendered required ebook facts: title, author, format,
language, meaningful page/file counts, and size. Its general description rules
require a representative image and content description. The operator's exact
presentation template remains a separate requirement; the page does not prove
that a particular template skeleton or label order is site-mandated.

The [ebook rules](https://c411.org/wiki/cat-ebook) repeatedly returned a server
error in the authenticated browser. Other wiki pages intermittently rendered
content and subsequently failed. Direct requests with the API key redirected;
the key did not grant wiki access equivalent to the browser session.

Current ebook eligibility, a measurable site cover-resolution rule, image-host
allowlist, and complete creation/publication policy could not be established.
Do not encode remembered rules or represent the local 600 × 900 portrait-cover
preference as a verified C411 minimum. These policy checks remain pending.
