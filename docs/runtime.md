# Supported runtime and verification

Verified on 2026-11-08 with Docker Engine 28.2.2 and Compose 2.36.2 on Linux
ARM64 containers. Docker Compose 2.24.4 or newer is required for volume overrides.
Windows hosts use Docker's Linux-container backend and a compatible POSIX shell.
Host and container paths remain independent deployment configuration.

The Ruby base is `ruby:4.0.9-slim-trixie` pinned to the multi-platform digest
`sha256:d8cb2c0714bdaba0f318af897a01d2dbde3cfa8e62d47e99cea55feb13c0e90d`.
Ruby and Rails use the supported patched releases selected from their official
[Ruby releases](https://www.ruby-lang.org/en/downloads/releases/) and
[Rails release announcement](https://rubyonrails.org/2026/11/4/Rails-8.0.5.2-and-8.1.4.1-have-been-released).
`Gemfile.lock` fixes the complete Ruby dependency graph for the image.

| Component | Verified version |
| --- | --- |
| Ruby / Rails | 4.0.9 / 8.1.4.1 |
| sqlite3 gem / embedded SQLite | 2.10.2 / 3.54.1 |
| SQLite schema/verification CLI | 3.46.1 |
| Puma / Solid Queue | 8.0.2 / 1.7.2 |
| RSpec Rails / SimpleCov | 8.1.0 / 0.22.0 |
| RuboCop / Rails Omakase | 1.92.2 / 1.1.0 |
| RuboCop Rails / Performance / RSpec | 2.38.0 / 1.27.0 / 3.10.2 |
| Capybara / Selenium / WebMock | 3.40.0 / 4.52.0 / 3.34.0 |
| Tailwind Rails / standalone compiler | 4.7.0 / 4.3.4 |
| Chromium / ChromeDriver | 156.0.8078.79-1~deb13u1 |
| Calibre | 8.5.0+ds-1+deb13u3 |
| Poppler | 25.03.0-5+deb13u4 |
| Tesseract / French data | 5.5.0-1+b1 / 1:4.1.0-2 |
| mktorrent | 1.1-3+b2 |
| Python / Pillow / ReportLab | 3.13.5-1 / 11.1.0-5+deb13u4 / 4.3.1-1 |

Debian packages resolve from Debian repositories, including security updates.
Record the built image identity and package report when comparing later builds;
the base digest alone does not freeze every repository package. Chromium and
synthetic fixture-generation dependencies are installed only in the quality stage.

## Commands

| Command | Behavior |
| --- | --- |
| `bin/setup` | Build the application image and prepare persistent app/queue databases. |
| `bin/dev` | Build and start web/worker; add `-d --wait` for background startup. |
| `bin/compose` | Run application Compose commands with the selected explicit env file. |
| `bin/test [RSpec arguments]` | Build and run isolated specs, with a printed reproducible seed. |
| `bin/lint` | Build and run all configured RuboCop checks, failing at refactor severity. |
| `bin/ci` | Run tests, coverage/lint gate probes, migrations, Zeitwerk, tools, and runtime recreation checks. |

The application image is immutable; runtime migrations update the mounted
SQLite databases without dumping schema into the image. Source changes require
rebuilding. State and queue files persist in the configured state volume, and
the application secret is kept in that volume rather than baked into the image.

## Acceptance evidence

A fresh clone without `.env`, operator ebooks, or private evidence passed
`bin/setup`, `bin/dev -d --wait`, seeded `bin/test`, `bin/lint`, and `bin/ci` with
host Ruby and Node absent from its executable search path. The initial foundation
passed six examples, including a real Turbo/Stimulus browser interaction and a
blocked unexpected HTTP request. The expanded domain/workflow suite passes
66 examples with 99.55% application line coverage; the enforced minimum is 90%.

Both unloaded-source probes failed coverage despite passing examples. Lint
probes failed for every configured department, formatting, and all four method
complexity limits; clean source passed. Application source and specs had no lint
offenses.

The runtime checks passed with disposable named volumes and with existing
synthetic host folders and container roots containing spaces. They verified
served assets, unprivileged storage access, same-inode rename, separate databases,
committed dispatch intents surviving process exit before queue insertion,
duplicate-delivery suppression, obsolete-result rejection after human edits,
recovery after killing a worker, and domain state/payload hashes surviving
container replacement. Cleanup removed only generated verification state.

These checks establish the application foundation. Operator authentication,
ebook workflows, provider actions, and acceptance on an actual deployment host
remain separate work. No live C411 publication or production Deluge operation
was performed. See [durable state](domain-state.md), [quality checks](testing.md), [storage configuration](storage-configuration.md),
and the earlier [provider/tool observations](provider-tooling.md).
