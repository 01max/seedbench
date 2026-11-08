# Portable mount check

This disposable Compose setup verifies a shared payload directory through
separate application and client container paths. It does not run Seedbench or
Deluge. Both containers run unprivileged, with no network, privileged mode,
Docker socket, application state, credentials, or real ebooks.

Create an empty disposable host directory and an ignored environment file such
as `private/storage.env`. Supply the host path using the syntax accepted by
Docker on that machine. For example:

```dotenv
PAYLOAD_HOST_PATH='/absolute/path/to/disposable folder'
APP_MOUNT_PATH=/payloads
DELUGE_PAYLOAD_ROOT=/downloads/books
PROBE_ID=mount-check
APP_UID=65534
CLIENT_UID=65533
SHARED_GID=65534
```

The existing directory must allow the application user to create probe
directories. The two users share a group so the client can read the prepared
`0640` file within its `0750` directory on a filesystem enforcing those modes.
Host file sharing can translate permissions; verify actual I/O rather than
assuming a group-ID change revokes access. Adjust the disposable directory's
permissions appropriately; do not apply these test permissions recursively to
operator payloads. `CLIENT_HOST_PATH`, when supplied, overrides the reader's
host source for a deliberate mismatched-mount check.

Run from the repository root:

```sh
docker compose -p seedbench-storage-check --env-file private/storage.env \
  -f script/storage/compose.yaml build
docker compose -p seedbench-storage-check --env-file private/storage.env \
  -f script/storage/compose.yaml run --rm app_view prepare
docker compose -p seedbench-storage-check --env-file private/storage.env \
  -f script/storage/compose.yaml run --rm client_view read
docker compose -p seedbench-storage-check --env-file private/storage.env \
  -f script/storage/compose.yaml run --rm app_view cleanup
```

Build context is limited to this directory. The writer reserves uniquely named
probe directories, writes fixed synthetic bytes exclusively, and checks a
same-device, same-inode rename with unchanged size/SHA-256 and no staged copy.
The reader checks those exact bytes through its own root and attempts a write
that must be rejected. Each command runs in a fresh container. Cleanup verifies
the synthetic hash before deleting only the probe file and its empty
directories; it does not recursively delete a mounted folder.

Repeat with another host directory and different container prefixes, including
spaces, to check that paths are configuration rather than constants. A duplicate
`prepare` must refuse an occupied destination. Missing/mismatched mounts,
insufficient client access, relative roots, invalid probe identifiers,
and staging on another filesystem must fail. To check a different filesystem,
run `app_view prepare` with `-e STAGING_ROOT=/tmp` and a fresh `PROBE_ID`; its
scratch tmpfs must not be accepted as same-filesystem payload staging.
The image also contains a root-owned `0700` directory at
`/restricted-probe-root`; pointing the reader's `SEEDBENCH_PAYLOAD_ROOT` there
must report a permission error. This is a native container-filesystem fixture,
independent of the host's bind-mount permission translation.

The real application must provide its own persistent operation journal, path
validation, recovery, and no-overwrite move implementation. This probe verifies
mount/permission/rename prerequisites and does not implement those workflows.
