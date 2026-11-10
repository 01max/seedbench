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
