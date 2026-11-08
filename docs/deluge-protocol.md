# Deluge protocol observations

Verified on 2026-11-08 with the [disposable protocol check](../script/deluge/README.md).
The runtime uses Debian Trixie's `deluged=2.2.0-1`, `deluge-web=2.2.0-1`, and
`python3-libtorrent=2.0.11-1`. A real daemon and web JSON-RPC endpoint run in one
unprivileged container with external networking disabled. The tracker and all
payload bytes are generated locally; no C411 or production Deluge connection is
used, and no ebook is mounted.
The verified platform was Linux ARM64 with Python 3.13.5 and UID 65534.

## Observed operations

| Operation | Request shape and observation |
| --- | --- |
| Web authentication | `auth.login(password)` establishes the session cookie. `web.get_hosts()`, `web.connect(host_id)`, and `web.connected()` select and verify the fresh daemon. |
| Paused import | `core.add_torrent_file(filename, base64_torrent, options)` returns the expected 40-character info hash. Options include `add_paused: true`, `auto_managed: false`, and the explicit client-visible `download_location`. Status reports `Paused` and the expected location. |
| Per-torrent move protection | `core.set_torrent_options([torrent_id], {move_completed: false})` changes the torrent's inherited value from true to false. The global value remains true. |
| Forced recheck | `core.force_recheck([torrent_id])` starts asynchronous checking. `web.register_event_listener("TorrentStateChangedEvent")` and `web.get_events()` observe the return to `Paused`, followed by a fresh status read. |
| Resume | `core.resume_torrent(torrent_id)` takes a scalar ID in this version. The complete fixture reaches `Seeding`, with tracker status `Announce OK` and a corresponding accepted loopback announce. |
| Pause | `core.pause_torrent(torrent_id)` also takes a scalar ID. The rejected fixture is observed returning to `Paused`. |
| Cleanup | `core.remove_torrent(torrent_id, false)` removes only the generated fixtures and preserves their data until the disposable container exits. |

`core.get_torrent_status(torrent_id, keys)` supplies state, progress,
`is_finished`, per-torrent options, download location, tracker status, total
bytes, and payload download counters. For small fixtures, the event sequence
can be `Seeding` then `Paused` without a visible `Checking` state. Returning
from `force_recheck`, or reading an already cached paused/100% status, does not
by itself establish completed checking. Drain prior events and require a new
return-to-paused event before accepting the result.

Forced rechecking temporarily resumes libtorrent internally. The local tracker
received announces for all three fixtures before an explicit resume request,
including the incomplete fixture. Paused import does not guarantee tracker
silence throughout a recheck. The probe observed the return to paused before
deciding whether the data could be explicitly resumed.

## Verified outcomes

- A complete 5 MiB fixture rechecked to 100%, reported `is_finished: true`,
  and resumed into `Seeding` with accepted tracker status.
- A half-length fixture verified only two complete 1 MiB pieces: 40% progress.
  It reported `is_finished: false`, returned to paused, and was never explicitly
  resumed by the probe.
- Another complete fixture rechecked to 100% and reached `Seeding`, while its
  tracker reported `Error: Synthetic tracker rejection`. This is a failed
  acceptance result despite the seeding state. The probe then paused it.
- All three payload SHA-256 hashes stayed unchanged, payload download counters
  stayed at zero, and the global completed-file move destination stayed empty.
- The entire global configuration matched before and after the protocol.
  No `core.set_config` call was made. The fresh fixture's initial global
  `move_completed: true` setting deliberately tests the per-torrent override.
- All three fixture torrents were removed without requesting data deletion.

Polling has a 20-second deadline per observation and seven-second HTTP request
timeouts. There is no continuing monitor. Tracker acceptance requires both the
daemon's status and a matching accepted announce recorded by the local tracker.
The tracker returns no peers, so this does not test peer transfers.

## Remaining deployment checks

This establishes the measured protocol for the packaged version, including a
negative tracker result. It does not establish another daemon's version,
credentials, permissions, daemon selection, configured payload mapping, peer
reachability, or real tracker policy. The [portable filesystem check](storage-configuration.md)
separately verifies configurable mount identities using synthetic data. Actual
host and client acceptance still require the selected deployment.

C411 publication, personalized site-issued torrent retrieval, and the complete
publish-to-seed workflow remain unverified under the current authorization.
No publication request was made.

References: [Deluge web JSON-RPC API](https://deluge.readthedocs.io/en/deluge-2.2.0/reference/webapi.html),
[Deluge core API](https://deluge.readthedocs.io/en/deluge-2.2.0/reference/api.html),
and [Debian's Deluge package](https://packages.debian.org/trixie/net/deluged).
