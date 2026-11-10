# C411 drafts

Connecting C411 imports its drafts as separate unlinked release shells. Opening
the workbench or choosing **Synchroniser maintenant** reads account state. A
similar title never links an uploaded file automatically. The link form requires
a file, a content choice and confirmation; it moves the active association onto
that file's release and preserves the former shell's content and history.
Unlinked shells can edit their name, title and description, but cannot prepare
or publish without a payload.

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

An unlinked shell updates only its reviewed name, title, description and changed
UTF-8 NFO. It preserves remote category/options, torrent and unrelated metadata.
It never invents a file or attaches another draft's torrent. New image URLs must
match a freshly verified selected cover. Imported NFO attachments use the API's
flat base64 write fields and object-shaped read representation; malformed or oversized content is rejected visibly.

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
