# C411 drafts

Connecting C411 or clicking **Importer les brouillons C411** in publishing
settings reads the account's draft list. New entries appear in the queue with an
**Import C411** label and their remote draft ID. Seedbench keeps a title and the
draft reference for each entry. You can archive or restore these entries locally.
Opening the workbench and switching filters use the local queue without contacting
C411. The draft panel on a local release with a linked draft has an explicit
**Synchroniser maintenant** action.

Synchronization compares local text and remote text with the retained common
base. Remote-only changes become local revisions; local-only changes stay unsent.
If both changed differently, the workspace retains all three versions. Choose
one explicitly after reviewing the comparison. Keeping local text does not send
it; choosing remote text creates a local revision and preserves prior text.

A conflict choice refreshes remote state and refuses a remote version that was
not shown. Every draft write must refresh before sending and read back afterward.
C411's tested stale timestamps, `If-Match` and `If-Unmodified-Since` headers did
not prevent overwrites, and its reads supplied no ETag or Last-Modified validator.
The application therefore cannot promise atomic remote compare-and-set: another
client can edit between the final read and write. Avoid concurrent editing from
the site during an explicit draft write. See [the observed API contract](c411-api.md).

**Créer le brouillon C411 / Mettre à jour le brouillon C411** first saves the
reviewed editor revision. Linked files require current preparation, independent
torrent verification, a freshly verified selected cover, and reviewed BBCode/NFO.
The first attempt may host the cover and stop until its URL is accepted through
the content review controls. Run the draft action again after acceptance. Hosting
receipts are reused and reverified instead of uploading the image again.

Writes retain the connection version, exact approved content, operation identity,
transmitted JSON and receipt. Categories/options for linked ebooks are resolved
from current account API reads. Slot counts are observations, and a provider
rejection keeps local work without deleting another draft or publishing. A
network error, invalid response or server failure after transmission is treated
as uncertain. Further writes remain blocked; **Vérifier le résultat sans
renvoyer** only reads and reconciles. For an uncertain creation, explicitly
confirm its remote identifier; the application verifies the approved content and
excludes drafts present before the attempt. It never guesses identity from a
similar title. An interruption before transmission can be closed without a
remote effect, then retried explicitly. Publication remains unavailable.

A confirmed draft-detail 404 marks the remote association missing. It never
deletes local text, evidence, prepared bytes or history. Authentication and
network failures do not count as deletion. Recreating a missing draft requires a
linked, prepared payload and a separate confirmation. The old association stays
until C411 returns the new identity; both sets of snapshots remain in history.
If the old draft reappears before transmission, recreation stops.

After publication, the read-only leftover observation reports whether the linked
draft remains. Its alert stays visible in the checklist and draft panel. Cleanup
requires confirmation of the displayed draft identifier and a fresh read that
still matches the displayed remote content. It never removes the canonical
payload or local release. A deletion timeout blocks another delete; reconciliation
only reads until absence is confirmed. This hook is tested with synthetic local
publication state; actual publication is still unavailable and unverified.

Each conflict copy displays French field labels and escaped BBCode/NFO. Sync
responses use the existing editor revision
check: unsaved browser text stays in place and requires a save-conflict choice
if remote-only adoption changed the saved revision.

Validation includes isolated CRUD, read-only imports, conflict/stale reads, remote
deletion, slot errors, authenticated/CSRF requests, Turbo forms at desktop/mobile
sizes, migration rollback/reapply, SQL request/body history guards, and durable
unknown-write/conflict records across all three disposable Compose layouts.
The 2026-11-10 live check used only synthetic torrent/NFO bytes and removed its
own uniquely marked draft; existing account drafts were unchanged.

Remote title/content adoption does not approve new edition facts. Review those
facts separately before regenerating or submitting a linked ebook.
