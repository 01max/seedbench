# Ebook workbench

![Dark desktop workspace with synthetic public-domain titles](images/workbench-dark.png)

The authenticated French workspace accepts up to 50 EPUB, PDF, or MOBI files per
batch, with a 100 MiB limit per file. Each accepted file creates an independent
release and records its original filename, byte count, and SHA-256. Rejected
files have individual errors; accepted files remain available.

Puma request bodies and Rack multipart files use private temporary storage under
the configured scratch volume, independently of the container's `/tmp` tmpfs.
Allow scratch capacity for both buffering layers (up to twice the batch size),
in addition to space for the accepted files on the payload volume. Temporary
buffers are removed after the request completes.

Uploads are streamed into private staging below the configured payload root.
Original bytes are retained. File extensions admit uploads; signature, structure,
encryption, and edition inspection are not implemented yet. A successful upload
therefore leaves inspection pending. Uploading makes no provider request and
does not prepare a torrent.

The queue pages through 40 releases at a time and searches actual titles and
authors without case or accent distinctions. State filters and previous/next
navigation retain the current search. The desktop layout keeps the compact
queue, full-text editor, and review checklist together; narrow screens stack
them without horizontal page scrolling. The toolbar opens upload, Settings,
appearance controls, and logout. Dark and light preferences persist locally.

Review, BBCode, NFO, files, history, sources, and preview have separate tabs.
Presentation, notes, complete BBCode/NFO, and reviewed title, author, ISBN,
edition, and language are editable. Source evidence and stored cover provenance
are shown on demand. Preview displays escaped local prose; BBCode rendering and
content validation remain pending.

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

Only the status frame refreshes during background work. Automatic reads are
limited to 30 per visit, at least 1.5 seconds apart with the default configuration;
completion, uncertainty, failure, or leaving the page stops them. Manual refresh
starts another bounded cycle. Status responses never replace editor fields, and
an older status response cannot undo newer review history.

Prepare, C411 draft, and Publish remain disabled. Their server endpoints save a
valid displayed revision before returning an explicit unavailable response.
Local editing, navigation, checklist changes, and shortcuts do not prepare files,
host covers, create drafts, publish, or start seeding.
