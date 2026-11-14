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
