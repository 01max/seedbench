# Ebook descriptions, NFO and local preview

Seedbench assembles content locally. These actions do not prepare a torrent,
host an image, create a C411 draft, publish, or invoke AI.

## Review and generate

1. Wait for inspection, then review title, author, publisher, publication year,
   language and ISBN in **Revue**. Adopt source candidates or enter known facts.
   **Valider les faits affichés** explicitly confirms unchanged displayed values;
   importing a filename or extracting metadata never performs that review.
2. Set **Nature de l’ISBN** deliberately. A print ISBN is recorded separately in
   the NFO and gives `Non applicable` in `ISBN numérique`. An unknown edition does
   not become a digital edition merely because its checksum is valid.
3. Write your presentation and optional notes. Choose **Proposer le BBCode** or
   **Proposer le NFO**. Pending edits are saved first; failed saves keep the text.
4. Compare the saved version and proposal, then choose **Accepter cette proposition**.
   Creation alone never changes BBCode or NFO. Each kind can be accepted separately.
5. Edit the complete BBCode and NFO at any time. Their full text is autosaved,
   retains revision history, and stays authoritative until an explicit replacement.

The description preserves the operator template's tags, blank lines and labels,
including `Notes supplémentaire :`. Required factual fields use reviewed inputs.
Unreviewed or missing facts remain `À renseigner`; they are not inferred from a
filename, a PDF creation date, a catalogue match, or AI prose. Generation still
works when incomplete, with visible validation reasons.

File format, exact size and meaningful counts come from successful inspection
of the current payload. A release contains one ebook file; EPUB spine documents
are labelled as documents, not physical pages. PDF page counts remain separate
from print-edition pagination. Size uses exact octets and decimal Mo/Go/To.
NFO and analysis material are never added to the ebook payload.

## Preview and validation

**Aperçu** renders the current BBCode, including unsaved text, without saving it.
It also retains the working presentation and notes below the description.
This is a safe close rendering, not an exact reproduction of C411's renderer.
Supported formatting includes emphasis, alignment, lists, quotations, code,
spoilers and bounded font/colour/size attributes. Video links remain passive.
Scripts, raw HTML, unsafe URLs and unsupported markup cannot execute.

Only the selected, previously verified hosted cover is loaded as an image.
Other image references remain placeholders, so arbitrary pasted image URLs do
not cause background image requests. Preview never hosts a cover or contacts
C411. It can read the already-hosted selected image when displayed.

The local C411 policy checks the exact description skeleton, unique label order,
size, balanced tags, safe attributes, factual consistency, and selected cover URL.
NFO checks require readable, nonduplicated title, author, format, language, file
count and size fields, accepting the documented English label variants as well. Recognized optional edition and measured-count fields
must agree with their sources. Unknown physical page counts are not invented.

C411's literal bracket escaping has not been proven. Generated bracket literals
use numeric entities for safe local display and receive a rendering-review
blocking diagnostic before a future remote write. A successful local preview
does not establish image-host acceptance or publication eligibility.

## Changed facts and preserved text

Each content revision records its payload, reviewed facts, relevant measured
counts, preparation/cover references, policy version and dependency fingerprint.
Material changes flag affected text **À relire** without replacing it. Presentation
or cover changes affect BBCode; preparation and measured page/document changes
affect NFO. Notes and shared edition facts can affect both.

You can create a new proposal, correct the saved text manually, or choose
**Conserver et valider le texte actuel** after reviewing it. Confirmation checks
factual and structural validity; it cannot clear mechanical errors. A proposal
cannot replace a newer edit or content whose dependencies changed. Retried
acceptance does not duplicate revisions or restore an older accepted version.

**Proposer l’URL de couverture** is a separate targeted proposal. It requires an
existing description in the ebook skeleton and an eligible hosted cover. Acceptance
changes only the cover URL, preserving the remaining bytes and manual prose.
No hosting occurs here. A new cover or later manual edit invalidates that proposal.

Proposals and accepted revisions survive application/container replacement.
Proposal bodies and provenance are append-only, including database guards.
The checklist derives its description/NFO result from current text, validation
and dependency state; a manual checkbox cannot manufacture completion.
