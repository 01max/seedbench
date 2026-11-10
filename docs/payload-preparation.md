# Canonical payload preparation

After successful inspection, review title, author and French-language evidence.
Choose **Suggérer un nom** to save a proposed listing name, then review it and
correct the team if the source team is known. This action saves local text and
leaves the uploaded file in staging. You can also enter a complete name manually.

Choose **Préparer** to save pending edits and queue preparation. The worker moves
that same file from private staging into the configured payload root, confirms
its original size and SHA-256, and creates a verified private single-file torrent.
There is no retained original copy, conversion, NFO, cover or analysis sidecar in
the torrent. The original upload filename remains in the release history.

The Files tab shows the canonical relative filename, torrent filename and info
hash. The checklist updates after completion. Local preparation never sends
anything to C411, Postimages, a tracker or Deluge. Provider accounts are optional
for this local work. The two existing web/worker containers perform it.

## Names and later edits

For example, the same book with an unknown source team uses:

| Purpose | Name |
| --- | --- |
| C411 listing | `Titre.Auteur.FRENCH.[EPUB]-NOTAG` |
| Canonical payload | `Titre.Auteur.FRENCH-NOTAG.epub` |
| Local torrent | `Titre.Auteur.FRENCH.NOTAG.torrent` |

PDF and MOBI use their corresponding format marker and extension. Keep a known
source team through the reviewed listing name. A series/volume may be included
when justified. The naming policy normalizes repeated NOTAG suffixes and rejects
paths, unsupported formats and video tags. It does not infer edition/year/team
from an uploaded filename or claim all reposts require a new filename. See
[C411 policy](c411-ebook-policy.md).

Changing the proposed name marks preparation stale. **Re-préparer** explicitly
renames the same canonical inode and verifies a new torrent; old preparation
records remain in history. Changes to measured bytes, missing files, a changed
mount or a torrent that no longer verifies also invalidate preparation when the release/status
is read. The original hash is never changed to bless modified bytes: restore the
correct mounted file or import the replacement as a new release. NFO dependency
changes require content review and preserve all manual text.

Published, submitting, outcome-unknown or seeded payloads cannot be renamed.
Preparation never automatically deletes or relocates seeded files. Editing,
navigation, autosave and shortcuts do not initiate preparation.

## Storage and recovery

Declare the payload folder through Compose. Staging lives under its private
`staging` child. `SEEDBENCH_PAYLOAD_ROOT` is the app's view of the shared folder;
`DELUGE_PAYLOAD_ROOT` independently describes the client's view. No host path is
stored in a release. The actual client mapping and read access still need
verification before any client action; preparation makes no RPC call.

The worker rejects traversal, symlinks in any path component, hard-linked source
files, unavailable roots and occupied destinations. A synthetic rename probe
checks service-user access and filesystem support before moving the book.
Linux `renameat2(RENAME_NOREPLACE)` prevents replacement even if another process
creates the destination after that check. The helper opens parent directories
without following symlinks. Cross-mount moves fail instead of copying data.
Filesystems must support this operation and file/directory synchronization.

A retained move journal records the original inode, filesystem identity, source,
destination and operation before rename. Destination reservations and a per-file
process lock coordinate web/worker attempts. After interruption, lease recovery
requeues this specifically recoverable filesystem operation. It reconciles a
finished rename by inode, hash and size before accepting the new locator. An
obsolete operation can reconcile location but cannot accept stale preparation or
overwrite newer text. A new mount cannot be substituted during that recovery.

A failed preparation keeps the book at its recorded or journaled location and
shows a diagnostic. Retry explicitly after fixing permissions, collisions or
mounts. If inputs changed while an earlier move was interrupted, the first retry
can finish reconciliation and report stale inputs; choose **Re-préparer** again
for the current reviewed name. Never manually remove journal records or move a
file to work around a collision.

A newly staged file is changed from private mode `0600` to `0640` on becoming
canonical so a configured shared group can read it. Existing files are not
recursively chmodded/chowned. Give Deluge read/traverse access through that group
and validate its actual view. State and scratch must be separate from the payload
root. Generated torrent artifacts stay private under the configured state root.
See [storage configuration](storage-configuration.md).

## Local torrent boundary

The local v1 torrent uses 1 MiB pieces, appropriate to the app's 100 MiB file
limit, the private flag and an inert `tracker.invalid` announce URL. This is a
local payload proof, not an upload-ready personalized tracker contract. Creation
contacts no tracker; a separate bounded bencode reader verifies single-file
inventory, exact UTF-8 name/size, private metadata and every SHA-1 piece, then
checks the original SHA-256 again. Reusing an artifact requires the same checks.

C411 draft/publication actions remain disabled. Personalized announce handling
and publication acceptance are not certified by local preparation. Future seeding
must use the torrent issued by C411 after acceptance, never this local artifact.
No publication-to-seeding claim follows from a successful local checklist item.
