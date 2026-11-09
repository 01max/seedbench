# Storage configuration

Storage is a deployment configuration. Seedbench works with directories mounted
into its containers; no host name, Unraid share, or host-specific absolute path
belongs in application code. George is the initial deployment target, not a
required filesystem layout or a prerequisite for portable development checks.

## Host paths and container paths

| Configuration | Meaning |
| --- | --- |
| Compose bind `source` | Existing directory on the Docker host, chosen by the operator. |
| `SEEDBENCH_PAYLOAD_ROOT` | Application-visible root matching the payload bind's `target`. Web and worker must use the same configuration. |
| `DELUGE_PAYLOAD_ROOT` | The torrent client's path to that same payload directory. It can differ from the application-visible root. |
| State and scratch roots | Separate application-visible directories with their own Compose volumes, binds, or temporary filesystems. |

For example, a host directory can be mounted at `/payloads` in Seedbench and
`/downloads/books` in Deluge. A relative payload locator `example.epub` then
resolves to `/payloads/example.epub` for the app and
`/downloads/books/example.epub` for the client. Translate the relative locator
under each configured root; do not replace string prefixes or send host paths
to Deluge. Persist relative payload locators, not deployment-host paths.

The application stack uses `compose.yaml` with named volumes by default.
Combine it with `compose.binds.yaml` to use existing host folders, configured
through `compose.env` as described in the root README. This is a representative
bind declaration:

```yaml
services:
  web:
    environment:
      SEEDBENCH_PAYLOAD_ROOT: /payloads
      DELUGE_PAYLOAD_ROOT: ${DELUGE_PAYLOAD_ROOT:?Set the client-visible root}
    volumes:
      - type: bind
        source: ${PAYLOAD_HOST_PATH:?Set the host payload directory}
        target: /payloads
        bind:
          create_host_path: false
```

Apply the same payload mount and environment to the worker. An existing Deluge
service separately mounts the same host directory at its chosen target, or an
equivalent shared filesystem verified to contain the same bytes. Deluge's own
configuration, plugins, credentials directory, and torrent inbox do not need to
be mounted into Seedbench. Client control uses its configured RPC connection.
Only files declared by the torrent enter its contents; neither a staging
directory nor unrelated files in the shared root belong in the torrent.

State and scratch use the same declaration pattern and can instead use named
volumes or tmpfs where appropriate. Those stores are not part of the payload
mapping. The application web/worker services validate writable roots on startup.
Production mount permissions and client identity still require deployment
acceptance; the executable example below is a separate filesystem probe.

The entrypoint defaults `TMPDIR` to a private `request-uploads` directory under
the configured scratch root. Puma and Rack use it for request and multipart
buffering before the accepted bytes are staged on the payload mount. Provision
scratch for up to twice the total upload batch size (up to 10 GiB for the
maximum 50 × 100 MiB batch), plus other temporary work. An explicit `TMPDIR`
override must be an absolute writable directory without a symlink and have
equivalent capacity. The isolated quality service uses its disposable `/tmp`.

## Filesystem requirements

Staging defaults to an application-owned directory within the configured
payload mount. This supports renaming the same file into its canonical name
without a second retained payload. A staging override is valid only if the
deployment preflight proves same-filesystem rename. Separate binds can cross
mount boundaries even when their host paths look related; fail with an
actionable configuration error rather than silently copying the file.

Use an application UID/GID with write/traverse access and give Deluge
read/traverse access to prepared payloads, for example through a shared group.
Verify access as the actual configured users; host file-sharing layers can
translate ownership and permissions. Root's successful access does not
prove that either service can read or write. Do not recursively change existing
payload ownership or permissions to hide a configuration error.

Validate allowed roots, relative locators, symlink escapes, destination
collisions, and actual size/hash identity. Changing a mount must trigger
revalidation before existing releases can issue filesystem or client actions;
it must not move, duplicate, or delete existing files automatically.

Docker-compatible Linux, macOS, and Windows hosts can supply their own bind
sources. Container roots remain Linux paths. Use the host's supported Docker
path syntax and file-sharing settings; filesystem permissions and rename
semantics still need to pass the preflight on that deployment. No claim of
testing every host OS or filesystem follows from a local probe.

References: [Compose bind declarations](https://docs.docker.com/reference/compose-file/services/#volumes)
and [Compose variable interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/).

## Executable filesystem check

The [storage probe](../script/storage/README.md) verifies independently chosen
host and container roots using only synthetic data. Its reader represents the
client's filesystem view, not a running Deluge daemon. Successful mount checks
do not establish RPC authentication, torrent recheck/seeding, tracker acceptance,
or deployment network access. The separate [Deluge protocol check](deluge-protocol.md)
exercises a disposable daemon; production deployment acceptance remains required.

### Verification on 2026-11-08

Docker Engine 28.2.2 and Compose 2.36.2 passed 26 checks across these layouts:

| Disposable host source | App container root | Client container root |
| --- | --- | --- |
| First test directory | `/custom/payloads` | `/external/downloads` |
| Nested directory with spaces | `/library mount/incoming` | `/different client/shared books` |

The app ran as UID 65534 and the reader as UID 65533, both with GID 65534.
Both readers saw the expected size and SHA-256 after same-inode rename, including
after reader-container recreation. Read-only client writes were rejected.
Occupied destinations, mismatched sources, denied access to a native container
directory, relative roots, traversal-like identifiers, missing host paths or
variables, and cross-filesystem staging all failed as expected. Missing bind
sources were not created. Cleanup preserved unrelated sentinel files.

This host's file-sharing layer also allowed a reader with another primary GID
to read the fixture. That observation reinforces checking effective service
access rather than treating numeric owner/group metadata as the complete
permission model. The definite permission-denial check used the container's
native filesystem. No production folders, credentials, or real ebooks were
mounted, and no real Deluge daemon was used.
