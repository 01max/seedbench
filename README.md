# Seedbench

A private, single-operator ebook preparation application built with Rails and
Hotwire. Versioned release state, recoverable background execution, operator
login, provider Settings, batch upload, and persistent local review are available.
Inspection, preparation, cover hosting, publication, and seeding remain pending.
Keep this development build bound to loopback.

Install Docker Engine and Docker Compose 2.24.4 or newer, and run the commands
from a POSIX shell (use WSL or a compatible shell on Windows). Ruby, Node,
SQLite, browser drivers, and ebook tools run inside containers.

```sh
bin/setup
bin/operator-password
bin/dev
```

Open <http://127.0.0.1:3000>. Setup builds the image and prepares both databases.
The password command prompts without echo; sign in with the password you set.
Development startup runs web and worker from the same image. Rebuild after source
changes; no host Ruby, Node, or ebook-tool installation is needed.

```sh
bin/test
bin/test --seed 41327
bin/lint
bin/ci
```

Tests and lint use a separate quality configuration with disposable tmpfs state,
no operator mounts, and no external network. CI also checks migrations, Zeitwerk,
coverage/lint enforcement, Linux ebook tools, assets, storage identity, and queued
work across actual container replacement. GitHub Actions runs `bin/ci` on pull
requests and pushes to main. See [quality checks](docs/testing.md).

Named volumes persist application state, the separate Solid Queue database,
scratch, and payloads across container replacement. The application secret is
initialized once in the state volume with restricted permissions. Preserve that
volume when replacing containers. `bin/compose down` stops the stack without
removing its persistent volumes.

Compose passes the configured service UID/GID and container roots to the image
build, so fresh named volumes inherit matching directory ownership. Rebuild with
`bin/setup` or `bin/dev` after changing those settings. Existing volume contents
retain their ownership; rebuilding does not change permissions on stored files.

To mount existing host folders, copy `compose.env.example` to the ignored
`compose.env`, set the three sources, and combine `compose.yaml` with
`compose.binds.yaml`. For example:

```sh
export SEEDBENCH_COMPOSE_ENV=compose.env
export COMPOSE_FILE=compose.yaml:compose.binds.yaml
bin/setup
bin/operator-password
bin/dev
```

Bind sources must already exist and be accessible to the configured service
UID/GID; missing folders are never auto-created. All application-visible roots
are configurable. Deluge's payload prefix is independent, and Deluge configuration
folders are not required mounts. See [storage configuration](docs/storage-configuration.md).

The application commands select an explicit Compose defaults file, so an
unrelated local `.env` is not loaded. Quality commands always select their own
configuration and ignore deployment overrides. Provider credentials are not
passed into containers by these configurations. Setup makes no provider calls.

Service ownership and error conventions are documented in
[application boundaries](docs/architecture.md). Records, revisions, history, and
background completion guarantees are described in [durable state](docs/domain-state.md).
Initialize or reset the operator password with `bin/operator-password` after
setup; see [operator access](docs/operator-access.md).
Configure provider credentials and connection checks in Réglages; see
[provider settings](docs/provider-settings.md).
Refresh model schema comments with `bin/annotate`; CI checks they stay current.
See [the ebook workbench](docs/workbench.md) for upload limits, saving, keyboard
navigation, review checks, and draft recovery.

Verified versions and fresh-checkout evidence are recorded in
[supported runtime](docs/runtime.md).
