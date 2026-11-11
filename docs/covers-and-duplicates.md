# Cover and duplicate review

## Choose and compare a cover

Open **Couverture** to compare embedded candidates, ISBN-linked Open Library
images, or a manually supplied PNG, JPEG or WebP. Online catalogue records retain
their source, queried ISBN, publisher, date and print/digital evidence. A print
record does not establish a matching digital edition. Compare the displayed
book facts with the actual file before confirming edition and image quality.

Selection stores the original image in private state storage and appends a cover
revision with its provenance, SHA-256, measured native dimensions and review.
It does not upload to Postimages. Local images are limited to 8 MiB, 20 million
pixels and 12,000 pixels per side. Remote images require public HTTPS destinations;
private addresses, mixed DNS answers, credential-bearing URLs and unsafe
redirects are refused. Animation is not accepted. No image is enlarged.

600 × 900 is a quality target, with smaller reviewed portraits allowed. Landscape
images additionally require an explicit comparable-detail review and explanation.
Changing the selected image, payload or material edition facts invalidates its
hosted eligibility without replacing saved description text.

## Hosting and description acceptance

The hosting service is reserved for an active, approved draft-write or Publish
operation. It records an intent before uploading and retains the returned page
and direct-link receipts. An uncertain upload stops instead of uploading again.
A known receipt can be verified again without another upload.

Verification loads the actual direct image from `i.postimg.cc`, checks its media
type and native dimensions, compares proportions and a reduced pixel signature
against the selected source, and rejects substantial downscaling or enlargement.
The selected source must already have a human edition and quality review. This
comparison detects changed images; it does not read an ISBN or certify image
sharpness. The proof records source and hosted hashes, edition facts and policy.
Reusing a hosted URL requires loading and checking its current bytes again.

**Proposer l’URL de couverture** creates a targeted proposal for the opening
cover URL in an existing valid description skeleton. Accepting it preserves every
other byte, including human prose and later occurrences of the previous URL.
A later text edit or cover change makes the proposal stale. Final action
validation requires current, reviewed BBCode/NFO, the exact selected verified URL,
and verification performed for that operation and attempt.

Explicit C411 draft actions now use these hosting and content-review gates.
Selecting a cover still cannot upload it. The automated checks isolate provider
writes; the live draft attachment check used only synthetic data. Publish remains
disabled. See [C411 drafts](c411-drafts.md) for the complete action flow.

## Search and review C411 candidates

Configure C411 and explicitly assign it to the release, then open **Doublons**.
**Rechercher sur C411** queues read-only searches for title variants, title with
author, and an available valid ISBN. Use **Actualiser les résultats** after the
worker finishes. The panel records searches, time, current edition/format inputs,
candidate titles, descriptions, detected format labels and clean detail links.
No equivalence is inferred from title similarity. API keys and credential-bearing
download URLs are excluded from saved results and browser responses.

Each query reads at most two pages of 100 results. A truncated or partly
unidentifiable feed stays incomplete; a failed query retains partial evidence
and a named availability failure. Neither condition becomes a clear search.

Every candidate starts as a possible match that blocks the duplicate gate.
Confirm a matching edition/format to apply **Doublon C411 déjà existant** and
block publication. Reject a false positive with an explanation of at least
20 characters. Decisions append history; changing a decision retains the old one.
A manual checklist mark cannot replace candidate review.

Reviews remain relevant across prose edits, but changed title, author, ISBN,
edition, publisher, language, year, payload or format requires review again.
New or changed candidate evidence also requires review. Known candidates remain
in the gate if a later feed omits them. A confirmed match remains visible until
an explicit reasoned decision clears it.

If search fails, **Recherche manuelle exceptionnelle** accepts a documented note
for the current search and inputs after checking read access to the assigned
C411 account. Record the variants, ISBN, edition and format checked and the
results. This exception addresses search availability only; it does not clear
known candidates, other checks, or establish permission to publish. It cannot
replace a truncated search or unavailable account access. A fresh failed search
requires a fresh manual note.

Publish starts with a fresh search before proceeding.
New candidates, changed evidence or a search failure stop it for review. The
current preview tests this boundary without enabling publication.

After a failed Publish search receives its manual review, a newly approved
continuation can finish that same check without starting another search. Its
immutable operation parameters record `manual_search_check_id`, the current
reviewed check ID. The boundary rechecks account access, current inputs and
candidate decisions. A newer search invalidates that continuation; an ordinary
Publish request performs a fresh search and a new failure needs a new note.
