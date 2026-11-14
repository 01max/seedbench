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
