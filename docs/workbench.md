# Ebook workbench

![Dark desktop workspace with synthetic public-domain titles](images/workbench-dark.png)

The authenticated French workspace accepts up to 50 EPUB, PDF, or MOBI files per
batch, with a 100 MiB limit per file. Each accepted file creates an independent
release and records its original filename, byte count, and SHA-256. Rejected
files have individual errors; accepted files remain available.

Choose **Importer des ebooks** to open the file picker. Selecting files starts
the import automatically after any pending editor changes are saved. The button
shows progress while importing. Success messages and per-file errors appear in
dismissible notifications; a completely rejected batch has no success message.

Puma request bodies and Rack multipart files use private temporary storage under
the configured scratch volume, independently of the container's `/tmp` tmpfs.
Allow scratch capacity for both buffering layers (up to twice the batch size),
in addition to space for the accepted files on the payload volume. Temporary
buffers are removed after the request completes.

Uploads are streamed into private staging below the configured payload root.
Original bytes are retained. File extensions admit uploads, then the worker
checks the actual format and structure. The checklist progresses from pending
to running, then succeeded or failed. Uploading makes no provider request and
does not prepare a torrent. Accepted uploads can still fail inspection.

Open **Sources** for source-linked metadata candidates, text samples, measured
counts, and embedded cover candidates. **Actualiser les sources** refreshes this
panel; **Relancer l’inspection** queues a fresh pass. **Analyser les pages avec
OCR** is available for PDFs. **Chercher l’édition** performs an explicit Open
Library ISBN lookup. **Adopter cette valeur** saves a chosen candidate with its
evidence link; it never silently replaces another field or your release text.
ISBN checksum validity alone does not establish edition authenticity. See
[inspection limits and evidence](ebook-inspection.md).

The queue pages through 40 releases at a time and searches actual titles and
authors without case or accent distinctions. State filters and previous/next
navigation retain the current search. The desktop layout keeps the compact
queue, full-text editor, and review checklist together; narrow screens stack
them without horizontal page scrolling. The toolbar opens upload, Settings,
appearance controls, and logout. Dark and light preferences persist locally.

Review, BBCode, NFO, files, history, sources, covers, duplicates and preview have separate tabs.
Presentation, notes, complete BBCode/NFO, and reviewed title, author, ISBN,
edition, and language are editable. Source evidence and stored cover provenance
are shown on demand. Preview renders current, including unsaved, BBCode safely.
Content generation creates proposals for explicit acceptance; dependency changes
flag text for review without replacing it. See the [content guide](ebook-content.md)
for metadata confirmation, NFO validation and targeted cover-URL proposals.

Use **Couverture** to compare and retain an image without uploading it. **Doublons** queues read-only C411 searches and records candidate reviews. See [covers and duplicate review](covers-and-duplicates.md) for image quality, known-match blocking and the manual-search exception.

Changes autosave after a short pause. Save acts immediately. Save and next,
previous/next links, filtering, and form actions flush pending edits before
continuing. Failed saves retain the entered text and selected release. Concurrent
edits show the saved values and require a deliberate choice to load that version
or save the entered values against its revision. Successful saves append durable
content and fact revisions rather than replacing history.

Keyboard controls:

- Ctrl/Command S saves the current text.
- Alt Up/Down saves and selects the previous/next matching release.
- Left/Right and Home/End move between focused workspace tabs.
- Tab reaches native fields, links, checklist controls, and actions.

The browser also retains unsaved values in session storage per release and tab.
A reload restores them; a changed server revision opens the same conflict choice.
Browser storage is optional and can be unavailable or cleared. Server-saved
revisions persist independently across application and worker replacement.

The checklist distinguishes automatic checks from reversible manual review.
Manual edition/text marks retain their history and record the revision reviewed.
Accepted uncertainties are bound to the finding revision. Mechanical failures
cannot be marked away.
Missing inspection, cover, or validated content stays visibly incomplete. Draft
linkage and automatic AI are optional; publication and seeding retain independent
outcomes.

The status frame refreshes during background work. Sources refresh on opening
the tab or through their explicit refresh link, without replacing editor fields. Automatic reads are
limited to 30 per visit, at least 1.5 seconds apart with the default configuration;
completion, uncertainty, failure, or leaving the page stops them. Manual refresh
starts another bounded cycle. Status responses never replace editor fields, and
an older status response cannot undo newer review history.

Use **Suggérer un nom** to save a deterministic candidate, review **Nom de
release**, then choose **Préparer**. Preparation moves the same file into the
configured canonical folder and verifies its private local torrent. Name or byte
changes make it stale until explicit **Re-préparer**. Files shows the results;
worker completion preserves newer dirty text through the conflict choice. See
[payload preparation](payload-preparation.md) for storage requirements, interrupted
moves and the inert local tracker boundary. C411 draft and Publish remain disabled;
their endpoints save a valid displayed revision before returning unavailable.
Local editing, navigation, checklist changes, and shortcuts do not prepare files,
host covers, create drafts, publish, or start seeding.
