# Seedbench

A private, single-operator ebook preparation application built with Rails and
Hotwire. The application foundation is available; ebook workflows and operator
login are still pending. Keep this development build bound to loopback.

Docker Engine and Docker Compose 2.24.4 or newer are required. Ruby, Node,
SQLite, and ebook tools run inside the image.

```sh
docker compose --env-file config/compose.defaults.env build
docker compose --env-file config/compose.defaults.env run --rm web bin/rails db:prepare
docker compose --env-file config/compose.defaults.env up -d
```

Open <http://127.0.0.1:3000>. Web and worker use the same image. Named volumes
persist application state, the separate Solid Queue database, scratch, and
payloads across container replacement. The application secret is initialized
once in the state volume with restricted permissions. Do not remove that volume
when replacing containers.

To mount existing host folders, combine `compose.yaml` with `compose.binds.yaml`
and declare `SEEDBENCH_STATE_SOURCE`, `SEEDBENCH_SCRATCH_SOURCE`, and
`SEEDBENCH_PAYLOAD_SOURCE`. Bind sources must already exist and be accessible to
the configured service UID/GID; missing host folders are never auto-created.
Application-visible roots and Deluge's payload root are configured independently.
See [storage configuration](docs/storage-configuration.md).

The commands explicitly select the checked-in Compose defaults, so the unrelated
local `.env` is not loaded. Deployment variables can be supplied with a separate
`--env-file`; credentials are not passed into containers unless explicitly
configured. No production provider calls occur during setup.
