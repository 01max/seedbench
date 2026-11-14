# Private deployment

Run the web and worker services from the same release checkout and image on the
Docker host. Use `compose.yaml` for managed volumes, or add `compose.binds.yaml`
when mounting existing host directories. Deluge needs a view of the same
canonical payload directory. The two services share state and scratch, but
neither requires Deluge's configuration, a Docker socket, or privileged mode.

## Choose mounts and service ownership

Copy `compose.env.example` to `compose.env`. If using bind mounts, set the
three existing host directories in that file and select the override:

```sh
export SEEDBENCH_COMPOSE_ENV=compose.env
export COMPOSE_FILE=compose.yaml:compose.binds.yaml
```

Use a nonzero `SEEDBENCH_UID` and `SEEDBENCH_GID`. On a Linux host, use
`id` and `stat` to inspect the existing accounts and directories. Give
Seedbench write and traverse permissions and Deluge read and traverse
permissions on the canonical path. A shared GID works with the prepared
files' mode `0640`. Set `SEEDBENCH_PAYLOAD_ROOT` to the mount target in
Seedbench and `DELUGE_PAYLOAD_ROOT` to the equivalent path in Deluge. See
[storage configuration](storage-configuration.md) for scratch capacity and
filesystem requirements.

Build and verify the mapped storage before initializing the application:

```sh
bin/compose build web
probe_id=$(openssl rand -hex 16)
bin/compose run --rm --no-deps -T --entrypoint ruby web script/deployment/storage.rb prepare "$probe_id"
bin/compose run --rm --no-deps -T --entrypoint ruby worker script/deployment/storage.rb read "$probe_id"
```

The first command checks state and scratch writes and an in-place rename
from staging to the canonical root. The second reads back the same bytes
under the worker's configured identity. Compare the reported SHA-256 with
`sha256sum` of the reported basename under the payload bind on the Docker
host and under `DELUGE_PAYLOAD_ROOT` inside Deluge. Run the Deluge read as
its **daemon's effective UID and GID**, using its existing container name.
A successful read as root does not establish the daemon's access.

```sh
docker exec --user "$DELUGE_UID:$DELUGE_GID" "$DELUGE_CONTAINER" \
  sha256sum "$DELUGE_CLIENT_ROOT/.seedbench-deployment-$probe_id.bin"
bin/compose run --rm --no-deps -T --entrypoint ruby web script/deployment/storage.rb cleanup "$probe_id"
```

Check all three hashes match before enabling publication. The probe only
creates and removes its own synthetic files. The client mapping check uses
Deluge's actual filesystem view, without adding a torrent or changing settings.

## Limit network access

Set `SEEDBENCH_LAN_ADDRESS` and `SEEDBENCH_TAILSCALE_ADDRESS` in
`compose.env` to the literal IPv4 addresses assigned to the Docker host.
Append `compose.private.yaml` to `COMPOSE_FILE`. For example, with bind mounts:

```sh
export COMPOSE_FILE=compose.yaml:compose.binds.yaml:compose.private.yaml
bin/compose config --quiet
```

The private override replaces the default loopback publication with bindings
for those two host addresses. Use a current Docker Engine and verify the
effective firewall policy for both addresses. On a routed LAN, enforce any
required ingress restrictions at the Docker host. Restrict Tailscale access
to the intended tailnet clients. Leave public forwarding, Tailscale Funnel,
and public reverse-proxy routes disabled. If using a single private interface,
set `SEEDBENCH_BIND_ADDRESS` in the base configuration instead.
[Docker port publishing](https://docs.docker.com/engine/network/port-publishing/)

After starting the stack, verify the bindings with `bin/compose ps`. From
a LAN client and a separate connected tailnet client, request `/up` and
open the login page at the respective address. From an unintended network
or interface, verify the web port is unreachable. On the Docker host, check
the worker has no published ports. Check the router and any existing proxy
for public forwards to the app. A single successful request does not
establish the denied paths.

## Initialize and start

Keep the same Compose project name and state mount for every command. Run
these from the deployment checkout with the environment and overrides
selected above:

```sh
bin/setup
bin/operator-password
bin/compose up -d --no-build --wait
```

The first run initializes the application and queue databases and generates the
application signing key and provider encryption key in the state directory.
Keep that directory private to the service account and back up both keys with
it. If supplying `SECRET_KEY_BASE` or `SEEDBENCH_ENCRYPTION_KEY` externally,
store those original values in the deployment's protected secret store as
well. Keep passwords and secrets out of command arguments, Git, and build
contexts. The password command reads twice from a terminal with input echo
disabled. Run it again on the deployment host to reset the password and
invalidate previous logins. [Operator access](operator-access.md)

Sign in once from a private client. In **Réglages**, configure and test the
C411, Deluge, and Postimages connections if using them. OpenAI is optional.
Review each default before uploading. Existing releases retain their pinned
connections. [Provider settings](provider-settings.md)

On the home LAN, plain HTTP sends login and session traffic without TLS.
Use it only on the trusted LAN. Tailscale protects traffic in transit between
its peers. For a TLS-terminating private proxy, keep the backend private and
set `FORCE_SSL=1` and `ASSUME_SSL=1` when the proxy forwards HTTP. With
end-to-end HTTPS, use `FORCE_SSL=1` and leave `ASSUME_SSL=0`.

## Upgrade or roll back

1. Finish or reconcile in-flight publication and draft writes, then stop both
   services and back up state. Record the running image ID, source revision,
   and effective Compose settings without copying credentials into notes.
2. Tag the current application image with a local rollback tag before building
   the new image. Select a new `SEEDBENCH_IMAGE_TAG` in `compose.env`. Keep
   the same state and payload mounts and the same encryption keys.
3. Update the checkout, run `bin/setup` to build and migrate, then run
   `bin/compose up -d --no-build --wait`. Check login, the queue, and a
   saved release before resuming operation.
4. Roll back to the previous image only if its code is compatible with the
   current database schema. Stop both services first, select the previous
   image tag, and start with `--no-build`. For an incompatible schema,
   use the recovery procedure below with the matching image and backup.
   Review remote activity after the backup before resuming.

An image rollback preserves the databases and canonical files. A state restore
cannot reverse C411 publication, draft changes, or Deluge state. Do not remove
the deployment's volumes or move seeded payloads during rollback.

## Back up and restore state

Finish remote writes and initial seeding, then stop both containers to
quiesce the separate application and queue databases at the same point.
Keep a copy of the selected image tag, checkout revision and Compose settings.
Use the state commands with the deployment's project and environment selected:

```sh
bin/compose stop
bin/state backup /absolute/protected/path/seedbench-state.tar.gz
bin/compose up -d --no-build --wait
```

The archive includes both SQLite databases, any SQLite sidecars, generated
state artifacts, and both effective recovery keys. Store it on separate
protected storage with restricted permissions and encryption at rest. The
archive can decrypt the contained provider credentials. The scratch mount
and canonical file mount are separate. Protect your payload share with your
normal storage snapshots or backups. Seedbench does not retain a second
working copy of an ebook.

Restore with the backup's matching image and Rails environment. Stop both
services, retain the current state mount, and point the deployment at a new
empty state directory or named volume. Keep the **same payload mapping and
files**. When keys are supplied externally, the configured values must match
the archive. Do not run `bin/setup` on the empty recovery volume first.

```sh
bin/state restore /absolute/protected/path/seedbench-state.tar.gz
bin/reconcile-state
```

The restore refuses nonempty destinations. An interrupted import can leave
the target volume incomplete. Keep it offline and restore again into a fresh
empty volume. Startup is suspended after restore. The reconciliation command
checks the current payloads and prepared torrent identities, then reads
known C411 drafts and submissions to compare them with saved records. It
reports release IDs that need attention. It blocks operation replay if the
backup captured a pending or ambiguous remote write or filesystem move. Local queued jobs are
retained.

Before restarting, verify the Deluge mapping with the storage probe. Review
C411 account history and Deluge for effects after the archive timestamp,
including new submissions and draft changes missing from the restored
database. If checks report differences or a remote operation is unresolved,
keep the recovered copy offline. Recover from a later consistent archive or
reconcile the affected records from the retained state and provider evidence
before proceeding. Once the checks pass and you have reviewed that history:

```sh
bin/reconcile-state --reviewed-remote-history
bin/compose up -d --no-build --wait
```

Verify the queue and a representative release after startup. The remote
history review is essential because a snapshot cannot contain IDs created
after it was taken.

## Deployment acceptance

Record the application revision, Docker Engine and Compose versions, and the
result of each host check. Keep host paths, credentials, personalized tracker
URLs, and private release identifiers in the deployment's own records.

| Check | Evidence to record |
| --- | --- |
| Storage and permissions | Web and worker ran as the chosen UID/GID. Their probe hash matched the host bind and the hash Deluge read as its daemon user. Staging rename preserved the inode. |
| Private network | The LAN and tailnet login pages and `/up` loaded from their intended clients. The port was unreachable from an unintended interface, and no public forwarding or public proxy route exists. |
| Access and restart | Operator login worked from a private client. Both services recovered after a restart with the same state and payload mounts. |
| Recovery | A matching image restored a protected archive into empty disposable state. The expected keys, edited content, queue and artifacts were usable, and reconciliation held the stack offline on a mismatch. |

The automated acceptance tests use disposable ebook bytes and stubbed external
write requests. They cover independent batch intake, same-file preparation and
single-team naming, deferred cover hosting, preservation of edits during AI
and draft sync, confirmed duplicate blocking and override, direct publication,
initial Deluge seeding, and persistent provider assignments. The manual path
test goes from ebook inspection through publication and initial seeding with
OpenAI returning an error. Run the complete set with `bin/ci`.

The [production C411 and Deluge result](c411-api.md#direct-publication-and-personalized-download)
covers an authorized existing draft approved by C411 and accepted by the tracker.
Use that result for the provider protocol check. Validate the actual Seedbench
container mount and private ingress on the deployment host. A repeat live
publication is unnecessary for those host checks.
