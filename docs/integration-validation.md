# Integration validation

Discovery performed on 2026-11-07. C411 category reads and an isolated draft
lifecycle have been verified. Synthetic Postimages/OpenAI checks and Linux
tooling checks are recorded in [provider and tooling observations](provider-tooling.md).
The [isolated Deluge protocol check](deluge-protocol.md) passed on 2026-11-08.
An authorized existing ebook draft was published and seeded on 2026-11-11.
See the [API observations](c411-api.md#direct-publication-and-personalized-download)
for the measured submission, download, and draft behavior.

## Provider checks

| Provider | Observed behavior | Verification still needed |
| --- | --- | --- |
| C411 | Category and option reads and isolated draft create/read/update/delete requests succeeded. | Profile access returned HTTP 403. Team Pending remains untested. |
| Deluge | An isolated Deluge 2.2.0 daemon passed paused import, per-torrent options, recheck, resume, seeding, and tracker acceptance/rejection checks. A live test also confirmed initial seeding. | Verify the actual mounts and daemon user access for each deployment. |
| OpenAI | A synthetic strict-schema request succeeded, and an invalid schema was rejected. | Test the connection and select a default in Seedbench settings. |
| Postimages | The upload helper authenticated and returned a loadable direct PNG for a synthetic image. | Hosting reduced 600 × 900 to 512 × 768; actual cover quality and C411 host policy remain to be verified. |

The authenticated C411 documentation is available at
[the integration guide](https://c411.org/user/integrations/guide). The
[2026-11-08 ebook policy review](c411-ebook-policy.md) records current rules and
the remaining undocumented contracts.

## Test-data boundary

The discovery check created, updated, and deleted an isolated test draft. The
Postimages check uploaded a synthetic checkerboard. The isolated Deluge check
imported and removed three synthetic torrents with external networking disabled.

For the live test, the payload was verified against the draft's torrent before
submission. C411 approved the release and supplied the personalized torrent.
Deluge verified 100% of the payload and the tracker accepted the seed.

## Remaining prerequisites

- Handle actual production slot-limit errors without filling the account's
  slots merely for a test.
- Make a deliberate OpenAI application connection assignment.
- Apply the dated ebook policy and resolve its remaining host, renderer, and
  publication-timing uncertainties before claiming those contracts work.
- Exercise draft lifecycle, concurrency and failures only against the identified
  test draft; record actual requests and responses with secrets redacted.
- Verify personalized torrent availability for a release held in Team Pending
  when an authorized release enters that state.
- The portable synthetic mount check passed. Validate the selected production
  host's actual app/Deluge mount identities and access during deployment.
- The isolated Deluge protocol check passed, including incomplete data and
  tracker rejection. Verify actual daemon access and real tracker acceptance
  separately during authorized deployment acceptance.
- Carry the measured provider limitations and selected Linux tools into the
  application image, with separate real-file, parser-bound, and hostile-input
  checks.

`bin/test`, `bin/lint`, and `bin/ci` run isolated checks with synthetic fixtures
and stubbed provider requests.
