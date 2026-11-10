# Quality checks

The quality image contains the application's locked dependencies and uses only
disposable tmpfs state. It has no operator mounts, injected provider credentials,
published ports, or external network. The ordinary application Compose file is
not merged into its configuration.

RSpec randomizes example order and prints the seed; pass `--seed NUMBER` to
reproduce it. Partial doubles are verified, and database examples use
transactional fixtures. Test builders create synthetic data in the configured
scratch filesystems rather than reading operator ebooks.

SimpleCov starts before Rails and application loading, with Bootsnap disabled.
Every Ruby file under `app` and `lib` counts, including unloaded source. Services
have a separate report group, and overall line coverage below 90% fails the run.
There are no business-code coverage exclusions. Reports default to the disposable
container's `/tmp/coverage` directory.

`script/quality/verify_coverage` copies the image's source into temporary storage
and tests unloaded probes in `app/services` and `lib` independently. Each child
run must pass its examples, confirm that its probe was not loaded, include the
probe as uncovered in the report, and exit unsuccessfully because of coverage.
Neither the image source nor the checkout is edited by this self-test.

RuboCop inherits Rails Omakase formatting and explicitly enables Lint, Security,
Rails, Performance, and RSpec. Application methods are limited to 15 lines,
ABC size 20, cyclomatic complexity 7, and perceived complexity 8. These method
limits apply to `app` and `lib`; spec DSL blocks are not application methods.
Integration examples allow up to 15 lines and five related expectations to keep
one action and its contract together. No application/spec files are excluded and
there is no generated TODO baseline.

`bin/rubocop` fails at refactor severity, covering convention and higher
severities as well. `script/quality/verify_lint` supplies disposable stdin probes
for each enabled department, all four complexity limits, and formatting; each
must fail. A clean source sample must pass. The probes do not edit source files.

Capybara uses Debian Chromium and its matching packaged ChromeDriver via an
explicit executable path, so Selenium does not download a driver during tests.
The appearance example loads controls into a Turbo Frame, checks that
the document was retained, changes the theme through Stimulus, and verifies the
local preference after a reload. Browser screenshots and reports remain in
disposable `/tmp/browser-artifacts` storage. Each scenario closes its browser
process, isolating browser state and avoiding Chromium refusing the driver’s
`about:blank` reset after earlier scenarios. Application navigation and reload
assertions still run in the real browser within each scenario.

Workbench browser checks cover the dark/light desktop palette and density,
320/390/736-pixel layouts, long metadata, keyboard focus and shortcuts, and an
85-release queue. Editing checks hold real save/status responses to exercise
typing during a save, Save and next, and older status arrival. Failed filtering,
navigation, concurrent edits, and reload recovery must preserve entered text.
Undo regressions cover returning to saved text before and during an in-flight
save. Two-client checks require loading unseen prose before reviewing its newer
revision. Duplicate filters follow the latest check for the current inputs.
Request checks reject forged automatic checks and verify that local work makes
no provider calls. All book names and content in these checks are synthetic.

Workbench copy is kept in `config/locales/workbench.fr.yml`. Request checks use
an alternate translated catalog to verify runtime labels, both Stimulus message
payloads, validation errors, and manual-review controls independently of display
labels. Machine state and review-owner codes remain independent of translations.

Chromium's `--no-sandbox` flag applies only to this unprivileged, synthetic,
network-isolated quality container. It avoids a privileged browser sandbox setup;
the container has no operator files or credentials. The application image does
not install Chromium.

WebMock denies unstubbed external HTTP while allowing the local browser server.
An integration example proves that an unexpected request raises before network
access; the Docker network boundary also prevents external browser requests.


The host entry points `bin/setup`, `bin/dev`, `bin/test`, `bin/lint`, and `bin/ci`
wrap Docker Compose. `bin/test` forwards RSpec arguments, including `--seed`.
`bin/ci` runs the same locked quality image and checks as local verification,
then verifies the production application image with disposable Compose projects.
No Docker socket is mounted into application or quality containers.

Access checks cover unauthenticated pages and actions, inherited artifact
responses, forged cookies, Devise inactivity expiry and active-session renewal,
password-reset revocation, HTTPS cookie flags, copied-cookie rejection after
logout, Devise session rotation, account locking and timed unlock, and invalid
CSRF tokens on authenticated writes. Migration checks retain the original bcrypt
hash through the Devise upgrade and rollback, revoke legacy cookies, and preserve
the single-operator constraint. The locking migration also retains sessions and
restores the legacy throttle constraints on rollback. Browser checks exercise
login, provider-specific credential forms, masked results, future-only defaults,
and deliberate release assignment. Adapter checks use WebMock and synthetic
credentials, including rejected redirects, oversized/invalid responses, network
failures, and a check completed after credential rotation.

The password console is tested through a pseudo-terminal with echo disabled.
The actual Rails runner also receives SIGIO during entry and confirmation in
a separate process and disposable database. It must retain the entered password
without echoing it; Ctrl-C must still cancel without initializing the account.
The actual runner command has also been exercised in disposable state, with the
synthetic password absent from its transcript and process arguments. No test
uses the deployment password command against operator volumes.

Model schema comments are maintained with [AnnotateRb](https://github.com/drwl/annotaterb).
Run `bin/annotate` after changing migrations or models. It builds the quality
image, prepares disposable databases, and annotates a temporary source copy,
then returns only model files to the checkout. No host Ruby, writable source
mount, operator data, or persistent application database is required.

Annotations include columns, indexes, and foreign keys, with database names
omitted so they are stable across environments. Specs, fixtures, factories,
and serializers are excluded. Development database tasks also refresh them
automatically in a writable source checkout; set `ANNOTATERB_SKIP_ON_DB_TASKS=1`
to skip that hook. CI runs `annotaterb models --frozen` against its disposable
database and fails when comments are stale. AnnotateRb is excluded from the
production bundle.

An isolated production-mode request check enables forced SSL without assumed
SSL and prepares its own disposable production databases. It requires plain HTTP
`/up` to return 200, application pages to redirect
to HTTPS, and requests forwarded as HTTPS to render normally.

The runtime check uses no network or published ports. It creates actual release,
payload, human-content, provider-assignment and event records, and verifies
served assets, non-root access, same-inode rename, and the loaded SQL history
guards. A producer process exits after committing its operation intent but
before queue insertion; the periodic recovery job must dispatch that operation.

The real `WorkflowOperationJob` then executes a synthetic compute/apply definition.
Repeated deliveries must create only one evidence record and completion event.
A computation is paused while a newer human edit commits; its late result must
be discarded. Another worker is killed during computation, recreated against the
same databases, and recovered with a new attempt token after the synthetic lease
is expired. Its old token cannot replace the accepted result. Finally web is
recreated and all retained domain state and payload hashes are checked.

Each runtime layout also saves full presentation, BBCode, and multiline NFO,
records a reversible review mark and uncertainty acknowledgement, and verifies
them after worker and web replacement. The authenticated editor is reopened and
parsed as HTML5 to check its actual textarea values and checked state.
It also submits two synthetic 80 MiB files through real Puma multipart HTTP,
with valid authentication and CSRF, while retaining the production 256 MiB
`/tmp` limit. Request buffering must use the configured scratch volume, and
both staged files must retain their original sizes and SHA-256 hashes.

This runs with default named volumes, alternate named-volume roots and UID/GID
65534, and existing synthetic bind folders/container roots containing spaces.
Cleanup removes only generated project volumes and temporary folders. Synthetic
bind contents are removed as the application UID after services stop, before
the host removes its generated parent folders. This preserves private staging
permissions even when the CI runner and application have different UIDs.
Synthetic handler definitions are installed only by the verification worker's explicit
fixture command. The production code-owned definition map does not pretend to
implement inspection, publication or other later feature handlers.

Each layout also initializes a synthetic operator, signs in through the real
production-mode HTTP endpoint with valid CSRF, and retains its browser cookies
across web recreation. It then verifies authenticated Settings, rejection of a
forged CSRF request, unchanged encryption-key hash and private key permissions,
decryptable credentials with ciphertext-only database storage, retained release
assignments and future-only AI/default choices, and browser-session revocation
after password reset. These hooks require the disposable runtime flag, use no
live provider checks, and keep the image-host test from uploading anything.

Production/test migrations do not dump schema into the read-only application
image. Schema updates belong in source changes; runtime migrations only update
the configured persistent databases. The quality source/build context is an
allowlist that excludes credentials, books, databases, extracts, and reports.

Preparation checks include no-replace collision handling, same-file identity,
symlink/traversal/mount failures, immutable move journals, stale and published-name
rejection, all supported format names, multi-piece hash mismatch, and dirty editor
preservation. Each Compose runtime mode kills a real worker after rename and before
locator commit, then verifies one recovered canonical inode, unchanged SHA-256 and
an independently checked private torrent after recreation.

The uncovered probe scales with the physical app/lib source size, with a minimum
of 240 lines. It remains large enough to fail the 90% gate even as the application
grows; successful examples must still exit unsuccessfully for each unloaded probe.
