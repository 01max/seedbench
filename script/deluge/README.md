# Synthetic Deluge protocol check

Build and run from the repository root:

```sh
docker build -t seedbench-deluge:verification \
  -f script/deluge/Dockerfile script/deluge
docker run --rm --network none --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=128m --cap-drop ALL \
  --security-opt no-new-privileges --pids-limit 128 --memory 512m --cpus 2 \
  seedbench-deluge:verification
```

Only this directory enters the build context. The container runs as UID/GID
`65534:65534`, with no host mounts, published ports, credentials, or external
network. It creates a fresh daemon, web UI, random local RPC credentials, three
synthetic payloads, and an HTTP tracker in disposable `/tmp` storage. All
connections use container loopback. The tracker returns no peers.

The check uses the web JSON-RPC endpoint to authenticate, connect to the known
fresh daemon, import paused, disable completed-file moves for each torrent,
force a recheck, resume a complete torrent, and observe both seeding state and
tracker acceptance. An incomplete fixture must finish checking paused. A second complete
fixture receives a deliberate tracker rejection and is paused after observation.
Each observation has a 20-second polling deadline; individual HTTP requests time
out after seven seconds. Processes are stopped on success or failure, and Docker
removes the disposable container.

Rechecks wait for a newly emitted return-to-paused event and a paused status.
Checking can finish too quickly to expose a `Checking` state. A previously
cached paused/100% response alone is insufficient evidence of completion.
The report includes the states actually observed. Deluge can briefly resume
internally and announce to the tracker during checking, including for incomplete
data; paused import does not promise tracker silence throughout a recheck.

The fresh daemon starts with global `move_completed: true` as a sentinel. No
global configuration write is made through RPC, and the full configuration
must match before and after the test. Each torrent must report
`move_completed: false`, the move destination must stay empty, every payload's
SHA-256 must stay unchanged, and payload download counters must remain zero.
Only the three generated torrents are removed, with data deletion disabled.

The image pins its Debian Trixie base by digest and Deluge packages at
`2.2.0-1`. Transitive packages resolve from Debian repositories; preserve the
JSON package report and built image identity when comparing runs. No host Ruby,
Python, or Deluge installation is required.

This verifies a local Deluge protocol, without publishing anything or contacting
a production client. It does not establish a selected deployment's credentials,
mounts, file permissions, peer reachability, personalized torrent handling, or
real tracker acceptance. See [the protocol observations](../../docs/deluge-protocol.md)
and the separate [portable mount check](../storage/README.md).
