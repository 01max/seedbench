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
The system example loads appearance controls into a Turbo Frame, checks that
the document was retained, changes the theme through Stimulus, and verifies the
local preference after a reload. Browser screenshots and reports remain in
disposable `/tmp/browser-artifacts` storage.

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

An isolated production-mode request check enables forced SSL without assumed
SSL. It requires plain HTTP `/up` to return 200, application pages to redirect
to HTTPS, and requests forwarded as HTTPS to render normally.

The runtime check uses no network or published ports. It verifies served assets,
non-root file access and same-inode rename, writes a synthetic primary-database
marker, removes a worker container, enqueues work while that worker is absent,
and recreates the worker against the same queue database. It then recreates web
and checks the saved primary state, job result, and unchanged payload hash. A
second run uses fresh named volumes at alternate container roots containing
spaces, with service UID/GID 65534, already present in the base image. A third
uses temporary host folders and container roots with spaces. Cleanup removes
only each generated project's volumes and temporary folders. The synthetic job
is loaded only through the smoke worker's explicit command; it is not part of
the application job namespace.

Production/test migrations do not dump schema into the read-only application
image. Schema updates belong in source changes; runtime migrations only update
the configured persistent databases. The quality source/build context is an
allowlist that excludes credentials, books, databases, extracts, and reports.
