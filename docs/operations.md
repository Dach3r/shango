# Shango — Operations

> How to run Shango in production: environment, deployment, backups and upkeep. Design notes live in [`architecture.md`](architecture.md) (§7 security, §8 deployment); API Client specifics in [`api-client.md`](api-client.md).

## 1. Deploying

- **Image:** `docker build -t shango .` builds a production image (Ruby, Thruster in front of Puma, port 80). Run it with `--env-file` and mount `/rails/storage` as a volume unless `SHANGO_STORAGE=s3`.
- **Processes:** one web process (the image default) and, in async execution mode (the production default), one Solid Queue worker: `bin/jobs` as a second container, or `SOLID_QUEUE_IN_PUMA=true` to run it inside the web process on small installs. Without a worker, requests sent from the API Client never finish (set `SHANGO_EXECUTION_MODE=inline` to run them in the web request instead).
- **Databases:** one PostgreSQL server with four databases (`shango_production`, `_cache`, `_queue`, `_cable`). The entrypoint runs `bin/rails db:prepare` before the web server starts. Splitting cache and queue onto their own server is a later optimization.
- **TLS:** the app forces SSL and assumes it sits behind a TLS-terminating proxy. Cap request bodies at the proxy as well (e.g. Thruster `MAX_REQUEST_BODY`).
- **Probes:** `/up` (booted) and `/ready` (booted and the database answers; 503 otherwise).
- **CI:** `.github/workflows/ci.yml` runs bundler-audit, importmap audit, Brakeman, Rubocop and RSpec (coverage must stay at 100%); `bin/ci` runs the same locally. The test job uploads the SimpleCov report to Coveralls (`coverallsapp/github-action`, authenticated by the GitHub token, no secret needed once the repo is enabled at coveralls.io). Dependabot opens weekly gem and Actions updates.
- **Commit lint:** `.github/workflows/commit_lint.yml` checks every non-merge commit subject of a pull request against `<emoji> <type>(<scope>): <subject>` using `bin/lint_commit_message`. The same script runs locally as the `.githooks/commit-msg` hook, enabled by `bin/setup` (`git config core.hooksPath .githooks`). Mark the `commit-messages` check as required in the branch protection settings to enforce it.
- **Contribution terms:** `.github/workflows/contribution_terms.yml` fails a pull request whose description does not have the license checkbox from `.github/pull_request_template.md` ticked (Dependabot and the repository owner are exempt). It re-runs when the description is edited. Mark the `terms-accepted` check as required in the branch protection settings to enforce it.

## 2. Environment reference

Required in production:

| Variable | Purpose |
| --- | --- |
| `SECRET_KEY_BASE` | Rails secret (sessions, signed cookies). |
| `SHANGO_DATABASE_PASSWORD` | PostgreSQL password for user `shango`. |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Encryption of stored secrets; the app refuses to boot without them. Generate with `bin/rails db:encryption:init`. Upgrading an install that used derived keys: `bin/rails shango:encryption:derived_keys`. Rotation: [`api-client.md`](api-client.md) §6. |
| `SHANGO_HOST` (and `SHANGO_PROTOCOL`, default `https`) | Host used in links inside emails, invitations included. Without SMTP nothing is emailed: owners copy each invitation link from the Members screen right after creating it. |

Optional, with defaults:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SHANGO_BLOCK_PRIVATE_NETWORKS` | `true` in production | `false` lets API Client requests reach localhost and private networks (self-hosted installs that call internal services; every project member can then send requests from the server into your network). |
| `SHANGO_EXECUTION_MODE` | `async` in production, `inline` elsewhere | Where API Client requests run. |
| `SHANGO_SMTP_ADDRESS` | unset | Turns email on. Also `SHANGO_SMTP_PORT` (587), `SHANGO_SMTP_USERNAME`, `SHANGO_SMTP_PASSWORD`, `SHANGO_SMTP_DOMAIN`, `SHANGO_SMTP_AUTHENTICATION` (plain), `SHANGO_SMTP_STARTTLS` (true), `SHANGO_MAIL_FROM`. |
| `SHANGO_REQUIRE_EMAIL_CONFIRMATION` | `true` when SMTP is set | `false` keeps email on without forcing confirmation. Ignored without SMTP. |
| `SHANGO_MAX_SIGN_IN_ATTEMPTS` | 10 | Failed sign-ins before a 30-minute lock. |
| `SHANGO_SESSION_TIMEOUT_HOURS` | 12 | Idle time before sign-in is required again. |
| `SHANGO_RATE_LIMIT_<NAME>` | see architecture §7 | `<count>/<seconds>` for `EXECUTIONS`, `DRAFTS`, `OAUTH`, `IMPORTS`, `SIGN_IN`, `SIGN_UP`, `PASSWORD_RESET`, `NETWORK`, `INVITATIONS`, `INVITATION_ACCEPTANCE`. |
| `SHANGO_CSP_REPORT_ONLY` | `false` | Report Content Security Policy violations without blocking. |
| `SHANGO_STORAGE` | `local` | `s3` for S3-compatible storage (`SHANGO_S3_BUCKET`, `SHANGO_S3_REGION`, optional `SHANGO_S3_ACCESS_KEY_ID`/`SHANGO_S3_SECRET_ACCESS_KEY`/`SHANGO_S3_ENDPOINT`). |
| `SHANGO_MAX_UPLOAD_MB`, `SHANGO_MAX_UPLOADS_TOTAL_MB`, `SHANGO_MAX_UPLOADS` | 10, 25, 10 | Upload limits per submission. |
| `SHANGO_HISTORY_RETENTION_DAYS` | 90 | Saved responses older than this are deleted daily (`0` keeps them). |
| `SHANGO_DRAFT_RETENTION_DAYS` | 30 | Request drafts (unsaved editor state) untouched for this long are deleted daily (`0` keeps them). |
| `SHANGO_NETWORK_HISTORY_RETENTION_DAYS` | 90 | Saved Network Tools runs older than this are deleted daily (`0` keeps them). |
| `RAILS_MAX_THREADS`, `WEB_CONCURRENCY` | 5, 1 | Puma threads (also the DB pool per process) and worker processes. |
| `JOB_CONCURRENCY` | 1 | Solid Queue worker processes. |

## 3. Backups and restore

All state is in PostgreSQL plus uploaded files:

- Dump the **primary** database (`shango_production`) on a schedule (`pg_dump -Fc`). The cache, queue and cable databases are disposable.
- Back up `/rails/storage` (or the S3 bucket) with the same cadence.
- **Keep the three `ACTIVE_RECORD_ENCRYPTION_*` values with the backup** (in a secrets manager, never next to the dump): without them every stored secret is unreadable.
- Restore: create the databases, `pg_restore` the primary dump, start the app (`db:prepare` creates the other three), restore the storage volume.
- Test a restore periodically.

## 4. Routine upkeep

- Recurring jobs (Solid Queue, `config/recurring.yml`): finished-job cleanup (hourly), orphaned upload purge (daily 3:00), saved-response retention (daily 3:30), Network Tools history retention (daily 3:45). They only run while a worker is up.
- Rotate encryption keys when someone with access leaves: [`api-client.md`](api-client.md) §6.
- Keep dependencies current (Dependabot PRs; CI runs `bundler-audit` on every push).
- Errors go to stdout with a request id (`log_tags`); ship them to your log platform. An error tracker (Sentry or similar) is not bundled; add one if you need alerting.

## 5. Known gaps (tracked, not blocking)

- **Team history:** `audit_events` are never purged. A project's history only grows by team changes (a handful of rows per change), so this is fine for now; add a retention job if it ever matters.
- **Existing data after roles shipped:** collections and environments created before `creator_id` existed have no creator, so only owners can change or delete them. Promote the right people to owner, or recreate the records, if members need to edit them.
- **Sidebar tree cache:** the workspace tree is loaded with three bounded queries per page (no request bodies) and is covered by a query-count spec; it is not cached because moves and bulk position updates would need reliable invalidation. Revisit when projects with thousands of requests show up in profiling.
- **Slow response headers:** the total deadline (`Executor::MAX_DURATION`) is checked between body chunks and redirect hops; a server that drips response *headers* is still bounded only by the per-read timeout.
- **Docker image:** the `Dockerfile` follows the Rails 8 pattern but has not been built in CI yet.

## 6. Seeds

`bin/rails db:seed` (also run by `db:setup` and `db:prepare` on a fresh database) loads `db/seeds/base/*.seeds.rb` in every environment and then `db/seeds/<environment>/*.seeds.rb` for the current one, alphabetically. Seeds must be idempotent. Put what the app needs everywhere in `base/`; production only ever loads `base/`.

`bin/reset_db` rebuilds the development database from scratch (drop, create, `db:schema:load` for every database including the Solid Queue one, seed, clear logs and tmp); pass `--no-seed` to skip seeding. Prefer it over `db:migrate:reset`, which overwrites `db/queue_schema.rb` with an empty schema because `db/queue_migrate` has no migrations.

- **Development account (development only):** `db/seeds/development/performance_account.seeds.rb` creates a single account, `dev@shango.test` (password `password`), with one project, "Restful Booker", imported through `ApiClient::Imports::Import` from the Postman collection and environment of the public Restful-Booker API (`db/seeds/development/fixtures/restful_booker.postman_*.json`: health, token auth, booking CRUD chain and negative cases, with `baseUrl` and credentials as variables). The `token` and `bookingId` variables are filled at runtime by Postman scripts, which Shango does not run, so set them by hand after calling `POST /auth` / `POST /booking`. Re-running leaves an existing account untouched; `SEED_RESET=1 bin/rails db:seed` rebuilds it.
