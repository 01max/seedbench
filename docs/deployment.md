# Private deployment

## Install from a published image on Unraid

In Compose Manager Plus, open **Add New Stack**, name it `seedbench`, and choose
**Git repository**. Use `https://github.com/01max/seedbench.git`, branch `main`,
and Compose path `deploy/compose.yaml`. You can also paste that file into a local
stack using the Compose editor.

In the stack's **Env** tab, set the version tag published in the
[Seedbench container registry](https://github.com/01max/seedbench/pkgs/container/seedbench)
and the host path to an existing payload directory. Set the address to your
Unraid LAN IP for direct LAN access. The default `127.0.0.1` works with a proxy
on the host. When using Deluge, also set its container-visible path to the same
directory.

```dotenv
SEEDBENCH_VERSION=<published version tag>
SEEDBENCH_BIND_ADDRESS=<private LAN IP>
SEEDBENCH_PAYLOAD_SOURCE=<absolute host payload directory>
DELUGE_PAYLOAD_ROOT=<matching path inside Deluge>
```

The image runs as UID `1000`. Give it write and traverse access to the payload
directory. Set `SEEDBENCH_GID` if the payloads should use a shared group other
than `1000`. Deluge needs read and traverse access as its daemon user. State and
scratch use Compose volumes. See [storage configuration](storage-configuration.md)
for permissions and capacity.

Save the environment and select **Pull and Redeploy** for a Git-backed stack,
or **Pull & Up** for a local stack. Seedbench prepares both databases before
starting the web server, then Compose starts the worker after web is healthy.
Open the `web` container's console and set the operator password once:

```sh
RAILS_LOG_LEVEL=error bin/container-entrypoint bin/rails runner script/operator_password.rb
```

Sign in on the configured address and port (default `3000`), then set up
provider connections under **Réglages**. Before publishing, verify that Deluge
can read the same payload bytes as Seedbench with the [storage probe](#verify-the-payload-mapping).

### Update a published-image stack

`main` supplies the Compose file. `SEEDBENCH_VERSION` selects the exact image
tag the stack runs. A new release leaves your selected version in place.

1. Finish in-flight work, stop the stack, and [back up state](#back-up-and-restore-state).
2. Change `SEEDBENCH_VERSION` in **Env** to the new published tag. Keep the
   Compose project name and storage mappings so the stack uses the same data.
3. Select **Pull & Up** to pull the new version and start the stack. Use **Pull
   and Redeploy** when you also want to apply changes to the Git-tracked Compose
   file. Once the services are up, check sign-in, a saved release, and the queue.

For backup and recovery via `bin/state` and `bin/reconcile-state`, run the
commands from a Seedbench checkout. Set `COMPOSE_FILE` and `SEEDBENCH_COMPOSE_ENV`
to the stack's Compose file and Env file, and `COMPOSE_PROJECT_NAME` to its
actual Compose project name. Use absolute file paths. Resume an image stack
with `bin/compose up -d --wait` after the checks pass.

### Publish a new image version

Push a new `v`-prefixed tag from a commit with the publish workflow. GitHub
Actions builds and smoke-tests the Linux `amd64` image, then pushes it to
`ghcr.io/01max/seedbench` under the same tag. After the first publish, set the
package visibility to **Public** in GitHub so hosts can pull anonymously.
Tags pushed before the workflow was added do not have a build from this workflow.

## Deploy from a source checkout

Run the web and worker services from the same release checkout and image on the
Docker host. Use `compose.yaml` for managed volumes, or add `compose.binds.yaml`
when mounting existing host directories. Deluge needs a view of the same
canonical payload directory. The two services share state and scratch, but
neither requires Deluge's configuration, a Docker socket, or privileged mode.

## Choose mounts and service ownership

Copy `compose.env.example` to `compose.env` and select it for both managed volumes and bind mounts:

```sh
cp compose.env.example compose.env
export SEEDBENCH_COMPOSE_ENV=compose.env
```

For bind mounts, set the three existing host directories in `compose.env` and
select the override:

```sh
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

## Verify the payload mapping

For a source checkout, run `bin/compose build web` before the storage probe.
For a published-image stack, select its Compose files, environment, and project
as described above and run `bin/compose pull`. Verify the mapped storage:

```sh
probe_id=$(openssl rand -hex 16)
bin/compose run --rm --no-deps -T --entrypoint ruby web script/deployment/storage.rb prepare "$probe_id"
bin/compose run --rm --no-deps -T --entrypoint ruby worker script/deployment/storage.rb read "$probe_id"
```

The `prepare` command checks state and scratch writes and an in-place rename
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

Check that the reported hashes match before enabling publication. The probe only
creates and removes its own synthetic files. The client mapping check uses
Deluge's actual filesystem view, without adding a torrent or changing settings.

## Limit network access

Seedbench publishes one HTTP endpoint. The default `SEEDBENCH_BIND_ADDRESS`
of `127.0.0.1` makes it available to the Docker host and a private proxy running
there. For direct LAN access, set `SEEDBENCH_BIND_ADDRESS` in `compose.env` to
the Docker host's LAN address. Use a current Docker Engine and verify the
effective firewall policy for the published port, especially on a routed LAN.
[Docker port publishing](https://docs.docker.com/engine/network/port-publishing/)

For tailnet access, use an existing Tailscale subnet route to the LAN endpoint
or a host-managed private proxy that forwards to Seedbench. Tailscale Serve can
forward to the loopback endpoint. The host's routing and access rules determine
which clients can connect. Leave public forwarding, Tailscale Funnel, and public
reverse-proxy routes disabled.
[Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)
and [subnet routers](https://tailscale.com/docs/features/subnet-routers).

After starting the stack, verify the published port with `bin/compose ps`.
Request `/up` and open the login page from each intended network. If the
deployment serves both LAN and tailnet clients, test each route from a separate
client. From an unintended network or interface, verify the web port is
unreachable. On the Docker host, check the worker has no published ports.
Check the router and any existing proxy for public forwards to the app.

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

On a LAN, plain HTTP sends login and session traffic without TLS.
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
backup captured a pending or ambiguous remote write or filesystem move, or if
C411 acknowledged a draft write whose readback failed or differed. Local queued
jobs are retained.

To retry readback for an acknowledged draft write while the recovered stack is
offline, substitute the reported operation ID in this command:

```sh
bin/compose run --rm --no-deps -T web bin/rails runner \
  'write = WorkflowOperation.find(OPERATION_ID).draft_write; Drafts::Reconcile.call(release_id: write.release_id, write_id: write.id)'
```

The readback must confirm the sent fields and attachments before it clears the
warning.

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
| Private network | The login page and `/up` loaded from each intended network. The port was unreachable from an unintended interface, and no public forwarding or public proxy route exists. |
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
