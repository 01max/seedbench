# C411 API observations

Draft discovery began on 2026-11-07 using the configured production key.
Publication and initial seeding were verified on 2026-11-11 with an existing
ebook draft authorized for that production test.

## Authentication and read access

For the JSON account/draft API, use HTTPS with `Authorization: Bearer <key>` and a descriptive application
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
file data in the JSON body. Reads expose `{name, data}` attachment objects,
but **writes use flat fields**: `torrentFileName`, `torrentFileData`,
`nfoFileName`, and `nfoFileData`. Sending the read-shaped objects on create was
accepted but silently omitted both attachments.

On 2026-11-10 the authenticated guide and official upload client serialization
were checked again. A uniquely marked synthetic draft verified dynamic ebook
category/options, private torrent bytes, UTF-8 NFO bytes, partial NFO replacement,
and removal using both NFO fields set to null. The test draft was deleted and
the original draft identifiers were unchanged. Only synthetic bytes were sent;
no publication request was made.

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

## Direct publication and personalized download

The authenticated guide documents direct `POST /api/torrents` using multipart
form data. It lists required torrent (maximum 10 MB), NFO (maximum 3 MB), title
(3–200 characters), description (at least 20 characters), category, and
subcategory. Options are encoded as JSON. The standard description format uses
BBCode; raw HTML requires an additional permission.

The production test submitted the saved title, torrent, NFO, categories and
options through that endpoint without a draft identifier. The API rejected
raw HTML with HTTP 403. A standard BBCode submission of the same reviewed
content succeeded with HTTP 200 and a `data` object containing the numeric
`id`, `infoHash`, and `status`. The response status was `approved`.
The original draft remained readable and its revision stayed unchanged.

`GET /api/torrents/{infoHash}` returned the submission's ID, name, status,
size, and creation time in a top-level JSON object. The detail response
reported `isOwner: false` even for the account that submitted it by API.
A nonexistent info hash returned HTTP 404. A missing or inaccessible detail
cannot rule out acceptance of an interrupted request. The authenticated guide says uploads can enter Team Pending. The
test did not exercise that state.

The Torznab download URL was established from an authenticated search
enclosure. `GET /api?t=get&id={infoHash}&apikey={key}` returned HTTP 200 and
`application/x-bittorrent` for the approved submission. Its info dictionary
matched the submitted torrent. C411 added its personalized announce URL.
The draft torrent had no announce URL. The production Deluge client imported
the site-issued torrent paused, rechecked the mapped EPUB at 100%, resumed it,
and reported Seeding and tracker acceptance. Private request evidence and the
personalized torrent are stored outside Git.

## Current ebook policy review

The wiki failed during the 2026-11-07 checks, but authenticated access recovered
on 2026-11-08. The [ebook policy record](c411-ebook-policy.md) now documents live
eligibility, names, description/NFO requirements, the standard editor's limits,
manual torrent settings, and the distinction between published site rules and
operator choices.

No numerical cover minimum was found in the reviewed pages; 600 × 900 is
the operator's portrait quality target, with smaller verified covers permitted.
The complete image-host allowlist,
Postimages acceptance in standard preview, and the API's seeding timing remain
unverified. Do not infer publication behavior from successful draft storage.

## Ebook duplicate search

Verified read-only on 2026-11-10 with explicit authorization to send the existing
key in an HTTPS query to C411. `GET /api?t=caps` returns public Torznab
capabilities; this does not verify authenticated search. The capabilities expose
`search` and `book-search` with `q`; the integration guide maps ebooks to Torznab
category `7020`, separately from the JSON upload category IDs above.

`GET /api?t=search&q=<query>&cat=7020&limit=100&offset=0` returned HTTP 401 with
Bearer authentication. Adding `apikey=<key>` returned HTTP 200 and an RSS feed.
The search client therefore sends that credential server-side in the query,
rejects redirects, disables implicit retries and proxy environment use, bounds
response size/time, and sanitizes failures. URLs with query credentials can be
retained by the remote service's infrastructure; they are never persisted or
returned to the browser by the application.

Observed items expose title, description, GUID, comments, link, enclosure,
pubDate, size, and Torznab attributes including infohash, category, size, seeders,
peers, grabs and volume factors. The application retains only bounded title and
plain description evidence, detected format labels, size and infohash. It builds
a clean `/torrents/<infohash>` detail URL instead of saving raw links or enclosure
URLs. It does not infer a confirmed edition from a similar title.

The live check was one bounded title search returning three items. Multi-query
searches, pagination, truncation, malformed responses and review gates are
covered by isolated HTTP tests. No publication request was sent.
