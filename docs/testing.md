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
