# Ebook inspection and edition evidence

An accepted upload queues a local, durable inspection. Keep the worker running.
Inspection does not prepare a torrent, select or host a cover, contact AI, or
write to C411. A successful inspection means that the measured checks completed;
it does not establish edition authenticity or prove that no pages are missing.

Open **Sources** to examine the evidence, rerun inspection, request PDF OCR, or
look up an ISBN in Open Library. The Sources refresh link and bounded checklist
refresh leave the editor intact. Actions first save pending edits. Adopting a
candidate appends a reviewed fact and an evidence link. Other candidates and
previous human facts remain in history. Concurrent edits require review rather
than automatic replacement.

## What is measured

| Format | Measurements | Sampling limits |
| --- | --- | --- |
| EPUB | ZIP signature, mimetype, member CRCs, safe package references, manifest/spine, embedded metadata, page markers, native raster covers | Text from the first two spine documents and the last; document and marker counts are not a physical page count. |
| PDF | PDF signature, Poppler structure/page count, embedded metadata, selected page text, first-page rendered cover candidate | First two pages and last page; pages with no extractible text are flagged for review. A rendered page is explicitly identified as a rendering. |
| MOBI | PalmDB/BOOKMOBI signature, record offsets/counts, compression/encryption flags, Calibre metadata and text extraction, embedded raster cover | Beginning/end text; Palm/text records and extracted characters are not page counts. |

Each text sample is at most 3,000 characters and names its archive entry, page,
or extraction position. Embedded identifiers retain their source; generic book
identifiers are kept distinct from ISBNs. EPUB font obfuscation is permitted;
unsupported content encryption stops inspection. Corrupt, password-protected,
mislabeled, unsafe, or oversized input produces a failure with a reason.

Optional French OCR renders the same selected PDF pages and runs Tesseract.
Images and text sidecars stay in a private scratch directory removed after the
attempt. OCR does not replace the PDF, change its payload locator, or add a
second ebook to the payload folder. Raster cover candidates are stored separately
under the configured state root and served only to the authenticated operator.
They remain unselected until the cover workflow is available.

## Edition review

An ISBN-10/13 checksum is a syntactic check. Equivalent ISBN-10/13 values are
compared consistently, but neither proves the edition. The explicit lookup sends
only the ISBN to Open Library's edition endpoint. Responses retain source URL,
time, identifiers, publisher/date and stated format. At most two same-origin
redirects are followed; response size is limited to 1 MiB and the whole HTTP call
to ten seconds. Unavailable or malformed records remain visible as lookup errors.

A print record associated with a scanned PDF stays print evidence. An online
scan or a record labelled ebook does not authenticate the supplied file as an
official digital edition. Compare the copyright/title-page samples and edition
notice, then deliberately accept facts or acknowledge unresolved uncertainty.

Mechanical failures cannot be acknowledged away. An invalid reviewed ISBN must
be corrected; an unreadable payload needs a successful fresh measurement.
Uncertainties have reversible acknowledgements tied to their exact finding
revision. Materially changed facts or measurements create another finding;
earlier acknowledgements stay in history. Identical measurements keep the
existing acknowledgement. Resolution appends history instead of deleting it.

## Parser budgets and storage

The parser receives an already-open read-only payload descriptor and no provider
credentials. Argument vectors invoke Python, Calibre, Poppler and Tesseract;
book contents are never shell commands. Ruby owns jobs, review decisions,
transactions and gates; the Python helper only extracts bounded measurements.
SHA-256, byte count and file identity are checked around parsing. No ebook is
rewritten or retained as a second canonical copy.

Each attempt has a 90-second wall deadline, 60 CPU seconds, 1 GiB address-space
limit per process, 32 MiB file limit, and 64 open descriptors. A tool command has
a 40-second timeout. The parent also stops attempts exceeding 64 MiB of scratch
output, 512 entries or 16 directory levels. Reports/tool logs are bounded at
256 KiB. The worker defaults to one job thread; additional worker processes must
be sized for these budgets.

EPUB archives allow at most 2,048 members, 8 MiB per member, and 128 MiB total
uncompressed data. Package XML is limited to 2 MiB; entity declarations and unsafe
paths are rejected. Internal parent references that remain inside the archive
are normalized safely. PDF inspection allows up to 2,000 pages. At most five
raster covers of 8 MiB and 40 million pixels each are accepted. Unsupported image
formats or inputs exceeding these budgets require an independently checked copy;
inspection never silently marks the file verified after a limit failure.

Scratch and cover artifacts use the configured scratch/state roots. Only the
accepted source lives under the payload root. Back up state with the application
database to retain evidence and cover candidates; no machine-specific mount
point is required.

Parser contracts follow the [Python ZIP documentation](https://docs.python.org/3/library/zipfile.html),
[XML safety guidance](https://docs.python.org/3/library/xml.html#xml-security),
[Calibre metadata CLI](https://manual.calibre-ebook.com/generated/en/ebook-meta.html),
and [Open Library edition/ISBN API](https://openlibrary.org/dev/docs/api/books).
