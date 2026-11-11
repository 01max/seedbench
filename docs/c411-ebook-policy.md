# C411 ebook policy

Authenticated documentation and the ebook upload form were reviewed on
2026-11-08 and rechecked through the authenticated browser on 2026-11-09. This records published rules and observed form behavior; it does
not establish publication acceptance on its own.
See [API observations](c411-api.md) for verified draft fields, attachment shape,
slot limits, responses, and the remote concurrency limitation.

## Eligibility and duplicates

The [ebook rules](https://c411.org/wiki/cat-ebook), last modified 2026-08-06,
accept French-language literature and EPUB, PDF, and MOBI. Other listed media
and formats do not expand Seedbench's supported scope. Generic RAR/ZIP/7Z
uploads, isolated chapters, incomplete comic packs without an exception, and
works without French are prohibited. The archive restriction does not prohibit
EPUB's own ZIP container.

A release in another format is not automatically a duplicate. The same format
with matching specifications is a duplicate. Search must therefore compare
actual edition/format evidence, including relevant packs, rather than only
filenames or ISBN. The stricter newspaper-pack rules remain outside this
single-ebook workflow.

## Names and original files

The [naming guide](https://c411.org/wiki/nommage), last modified 2026-11-03,
gives these listing patterns:

| Work | Listing pattern |
| --- | --- |
| Standalone | `Titre.Auteur.Langue.[Extension]-Team` |
| Series/volume member | `Titre.Type d'ensemble.Auteur.Langue.[Extension]-Team` |

Use dotted words, retain a known source team, and use `-NOTAG` when the source
team cannot be found. Preserve literal format brackets. Series/volume and year
must be justified; year is required to distinguish versions or reboots.

The guide explicitly distinguishes the listing title from an existing repost's
payload filename and instructs preserving the latter. Seedbench's explicit
canonical-rename workflow is an operator choice, not a claim that C411 requires
all reposted files to be renamed. Existing torrent-bound or published payloads
must retain their expected names. Keep release, payload, and `.torrent` naming
separate; the operator's unknown-team torrent suffix is `.NOTAG.torrent`.

## Description and NFO

The [description/NFO rules](https://c411.org/wiki/description-nfo), last modified
2026-10-25, require a representative image, content description, and an accurate,
readable NFO. Required ebook facts are title, author, format, language,
meaningful page/file counts, and size. Image-based formats also require average
image resolution. Unknown facts must not be invented.

The live Ebook → Livres form calls its NFO attachment optional, while the wiki
and API upload guide require it. Retain the stricter publication requirement;
an incomplete draft can exist without satisfying it. The form's optional flag
does not waive the published rule.

The operator's description format has this label order: cover, centered title,
`Auteur(s) :`, `Éditeur :`, `Parution :`, `ISBN numérique :`, `Langue :`,
`Présentation :`, `Fichier(s) :`, `Taille :`, and `Notes supplémentaire :`.
Preserve the established tags, whitespace, labels, and order. This exact format
is an operator requirement; the wiki permits presentation customization.

Use an actual digital-edition ISBN only. A scan's print ISBN is not a digital
ISBN; document it separately and use `Non applicable` where appropriate. Report
exact payload bytes with decimal readable units. Keep NFO and analysis sidecars
outside the single-file payload torrent.

## BBCode and observed limits

The authenticated [API guide](https://c411.org/user/integrations/guide) documents
`descriptionFormat=standard` for BBCode. Its listed tags are `b`, `i`, `u`, `s`,
`url`, `img`, `color`, `size`, `quote`, `code`, `list`, `youtube`, `spoiler`,
`center`, `left`, `right`, `font`, `hr`, `h1`–`h5`, and `table`.

| Boundary | Evidence |
| --- | --- |
| Draft slots | Guide maximum 15; prior authenticated list also returned `maxAllowed: 15`. |
| Published title | Guide: 3–200 characters. |
| Description | Guide: at least 20 characters; live standard editor displays 15,000 maximum. Server-side maximum was not probed. |
| Moderator note | Live form displays 500 characters maximum. |
| Publication attachments | Guide: torrent maximum 10 Mo; NFO maximum 3 Mo. The upload-byte boundary was not tested. |
| Draft attachments | Guide: base64 in JSON; observed object fields are `name` and `data`. Attachment round trips remain unverified. |

A tag list does not establish every nesting, escaping, or renderer rule. Literal
bracket escaping and malformed-tag handling remain unverified. Local preview
must sanitize active content and unsafe links without claiming exact site
rendering. The local content policy preserves the operator template and applies
bounded, conservative tag/attribute rules. Generated literal brackets use numeric
entities for safe local display; because C411's literal escaping remains unproven,
those descriptions receive a blocking rendering-review diagnostic before remote
submission. This does not silently establish a site escaping contract. HTML is a separate permission-controlled format and must not be
silently substituted for BBCode.

## Cover quality and allowed hosts

The reviewed ebook, description, upload, creation, and publication pages require
a representative image but do not specify a numeric cover-resolution minimum.
The operator quality target is **600 × 900 native pixels at the exact hosted
URL**, rather than a minimum requirement. A smaller verified portrait is usable
when it is the available cover; a small image is preferable to no image. Prefer
native detail over enlarged thumbnails. Edition correspondence, visible
sharpness, compression artifacts, and watermarks require review. Other aspect
ratios need documented comparable-detail review; no automatic acceptance
threshold is asserted for them.

Check both source and hosted dimensions. The synthetic Postimages check served
512 × 768 from a 600 × 900 source. It falls below the quality target but remains
usable as a smaller cover.
That observation does not establish whether C411 accepts the host.

The [HTML presentation policy](https://c411.org/wiki/prez-html), last modified
2026-10-27, says off-allowlist images become text links and gives a non-exhaustive
list including TMDB, imgbox, pixhost, zupimages, noelshack, casimages, and imgur.
Postimages is not named in that example list; absence is not proof of rejection.
A complete host allowlist and acceptance of the selected Postimages URL in a
standard BBCode preview remain unverified. Do not infer those contracts or
represent a reachable direct image as proof of C411 acceptance.

## Torrent creation and seeding timing

The [creation guide](https://c411.org/wiki/creation-torrent), last modified
2026-01-24, requires a fresh private torrent and the account's personalized
announce URL. Never expose the passkey. Its manual piece-size table is:

| Payload size, as written in the guide | Piece size |
| --- | --- |
| Below 1 Go | 1 Mo |
| Below 2 Go | 2 Mo |
| Below 3 Go | 4 Mo |
| Below 8 Go | 8 Mo |
| Above 8 Go | 16 Mo |

The guide advises choosing the size explicitly and warns about torrents above
16 Mo. The API's documented torrent upload limit is stricter at 10 Mo. Exact
threshold equality and the integrated creator's settings were not validated.
The isolated Linux probe's inert torrent exercises tool/hash behavior, not
compliance with this creation policy.

The [publication prerequisites](https://c411.org/wiki/publication-seed), last
modified 2026-02-10, require seeding at submission and availability through at
least one complete additional download. The creation guide also asks for
immediate seeding. This differs from the intended submit-then-retrieve-and-seed
sequence. Whether the API accepts a pending submission before seeding, and the
actual timing permitted before validation, remain untested. Documentation alone
does not resolve that integration dependency.

A later authorized production test verified an approved submission followed
by personalized download and initial seed. Prepare the canonical payload
on the Deluge filesystem before submission so that it can be rechecked and
shared immediately after acceptance. The test did not exercise Team Pending.
See the [API observations](c411-api.md#direct-publication-and-personalized-download).
