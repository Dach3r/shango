# Shango

**Open source Developer Workspace.** One project-centered place where a web developer's API client, network tools and (on the roadmap) documentation, monitors, servers, logs and AI share the same context.

Shango is a Rails 8.1 monolith (PostgreSQL, Hotwire, Tailwind, ViewComponent, Solid Queue). It is self-hostable, framework-agnostic and licensed under AGPL-3.0.

> Shango is under active development. This README describes what exists in the repository **today**; vision and roadmap are in [`docs/product.md`](docs/product.md). When in doubt, the code is the source of truth.

## Table of contents

- [What is Shango?](#what-is-shango)
- [Why it exists](#why-it-exists)
- [Current status](#current-status)
- [Features](#features)
  - [API Client](#api-client)
  - [Network Tools](#network-tools)
  - [Projects, environments and accounts](#projects-environments-and-accounts)
- [Roadmap](#roadmap)
- [Tech stack](#tech-stack)
- [Requirements](#requirements)
- [Getting started](#getting-started)
  - [1. Clone](#1-clone)
  - [2. Install system dependencies](#2-install-system-dependencies)
  - [3. Set up the app](#3-set-up-the-app)
  - [4. Run it](#4-run-it)
  - [5. Create your account](#5-create-your-account)
  - [Development seeds](#development-seeds)
  - [Useful development commands](#useful-development-commands)
- [Configuration](#configuration)
  - [Development](#development)
  - [Production environment variables](#production-environment-variables)
- [Running the tests](#running-the-tests)
- [Code quality and CI](#code-quality-and-ci)
- [Project structure](#project-structure)
- [Conventions](#conventions)
- [Deployment](#deployment)
  - [Running with Docker](#running-with-docker)
  - [Deployment notes](#deployment-notes)
- [Backups and upkeep](#backups-and-upkeep)
- [Security](#security)
- [Documentation index](#documentation-index)
- [Contributing](#contributing)
- [License](#license)

## What is Shango?

Shango is a **Developer Workspace**: a web application that centralizes the tools a developer uses to build, test and operate web applications, organized **by project** instead of by tool.

Everything lives inside a *project*. A project has its own environments (Local, Staging, Production…), variables, collections of HTTP requests and network checks. Data from one project never leaks into another.

One-liner: *one project-centered workspace where your API client, docs, monitors, servers, logs and AI share the same context.*

Who it is for:

- Independent developers managing several projects, clients, APIs and servers (primary persona).
- Small development teams that need to share environments and tools.
- Backend and full-stack developers who work with APIs, infrastructure and debugging every day.

What it is **not**: an IDE replacement, a language-specific tool, a SPA or a microservices system.

## Why it exists

Developers juggle many independent tools for testing APIs, documenting them, monitoring services, managing servers, reading logs, tracking errors and asking generic AI chats. That causes fragmented information, duplicated configuration (the same URL and token entered in every tool), constant context switching and AI that knows nothing about the failing request.

Shango's bet is that these capabilities should be **related and share context**: configure an environment once and use it everywhere; turn a request into a documented endpoint and a monitor without configuring it twice.

Differentiators:

1. **Shared context** across tools.
2. **Project-first** organization.
3. **Contextual AI** (roadmap).
4. **Self-hostable and open source**, with no mandatory commercial services.
5. **Framework-agnostic.**

## Current status

| Area | State |
| --- | --- |
| Authentication, projects, environments, settings | Available |
| API Client (collections, requests, execution, imports, auth strategies) | Available |
| Network Tools (DNS checker, port check, TCP ping) | Available |
| API documentation (OpenAPI), monitoring, notifications | Roadmap |
| AI assistant, server management / SSH, logs, integrations | Roadmap |

Navigation entries for unbuilt features render disabled with a "Soon" badge; nothing is presented as available before it exists.

Known gaps (tracked in [`docs/operations.md`](docs/operations.md) §5): project roles (`owner` / `member`) exist in the data model but are not enforced yet, so every member of a project can do everything inside it. There is no invitation flow yet.

## Features

### API Client

An HTTP client for building, organizing and running requests, available at `/workbench`.

- Collections with nested folders and requests; drag and drop to reorder and move.
- Requests open as per-user tabs, with drafts that can be saved or discarded.
- Request editor: method, URL, query params (kept in sync with the URL), headers, body and authorization.
- Body types: none, JSON, text, XML, GraphQL, form-urlencoded, multipart (text and file fields) and binary file.
- Environments with `{{variable}}` interpolation, secret variables and a per-member active environment. The code editor (CodeMirror 6) autocompletes and highlights variables by state.
- Authorization per request or per folder with inheritance: None, Basic, Bearer, API key, JWT bearer, Digest, AWS Signature v4 and OAuth 2.0 (client credentials, password, authorization code with PKCE, automatic refresh).
- Response viewer: pretty / raw / HTML preview, headers, request details (redirect chain), history and cookies.
- Import and export: import a cURL command, copy a request as cURL, import whole collections and environments from the export files of other API clients and from OpenAPI specifications.

Not included yet: pre/post-request scripts, assertions, collection runner, WebSocket/gRPC, collection export. Full detail in [`docs/api-client.md`](docs/api-client.md).

### Network Tools

Quick checks for the moments when you are configuring a server, at `/network`:

- **DNS checker**: does a record match what you expect on public resolvers and on the authoritative nameservers (has it propagated)?
- **Port check**: which ports are reachable from the outside.
- **TCP ping**: is the host online.

Targets can use environment variables such as `{{host}}`. Runs are kept as per-project history and purged after a retention period. See [`docs/network-tools.md`](docs/network-tools.md).

### Projects, environments and accounts

- Sign up, sign in, password reset and optional email confirmation (Devise).
- Every user creates a first project on sign-up and can switch between projects from the status bar.
- Per-membership preferences and themes.
- Interface available in nine languages: English (default), Spanish, Simplified Chinese, Hindi, Brazilian Portuguese, Russian, Japanese, German and French.

## Roadmap

Indicative order, from [`docs/product.md`](docs/product.md) §14:

| Phase | Name | Scope |
| --- | --- | --- |
| 1 | Foundation | Authentication, projects, environments, settings, main layout |
| 2 | API Client | Collections, nested folders, requests, HTTP execution, responses |
| 3 | Documentation & Monitoring | OpenAPI, monitors, scheduler, incidents, notifications |
| 4 | AI Assistant | Configurable providers (BYOK), contextual chat, error analysis |
| 5 | Server Management | Servers, SSH, integrated terminal, assisted diagnosis |
| 6 | Developer Operations | Logs, webhooks, GitHub, CI/CD, additional tools |

Network Tools sits outside the phases on purpose: it only depends on projects and environments.

## Tech stack

| Layer | Choice |
| --- | --- |
| Framework | Ruby on Rails 8.1 (MVC monolith) |
| Language | Ruby 4.0.4 (see `.ruby-version`) |
| Database | PostgreSQL |
| Views | ERB |
| Frontend | Hotwire (Turbo) + Stimulus, importmap, no Node build step |
| Styling | Tailwind CSS (`tailwindcss-rails`) |
| UI components | ViewComponent, Lucide icons |
| Authentication | Devise |
| Background jobs | Active Job + Solid Queue |
| Cache / Cable | Solid Cache / Solid Cable |
| Assets | Propshaft |
| HTTP client | Faraday |
| Code editor | CodeMirror 6 (vendored) |
| Tests | RSpec, FactoryBot, shoulda-matchers, WebMock, Capybara + Cuprite |
| Quality | Rubocop (`rubocop-kode`), Brakeman, bundler-audit, SimpleCov |
| Production | Docker, Thruster in front of Puma |

There is no separate frontend and no Node toolchain: JavaScript is served through importmap.

## Requirements

- **Ruby 4.0.4** (matches `.ruby-version`; use rbenv, asdf, mise or similar).
- **PostgreSQL** (CI runs 17). A local server reachable through the default Unix socket, with a role that can create databases (by default the role named like your OS user).
- **libvips** (image processing for Active Storage variants).
- **libpq** headers (to build the `pg` gem) and a C toolchain.
- **Git**.
- **Docker** only if you prefer to run the production image (see [Running with Docker](#running-with-docker)).
- **Foreman** (installed automatically by `bin/dev` if missing).
- **Google Chrome / Chromium** only if you want to run the system specs.

## Getting started

### 1. Clone

```bash
git clone https://github.com/Dach3r/shango.git
cd shango
```

### 2. Install system dependencies

macOS (Homebrew):

```bash
brew install postgresql@17 libvips
brew services start postgresql@17
```

Debian / Ubuntu:

```bash
sudo apt-get install -y build-essential libpq-dev libvips libyaml-dev postgresql
```

Make sure the right Ruby is active (`ruby -v` must print 4.0.4).

If your PostgreSQL requires a password or a non-default host, export `DATABASE_URL` or the standard `PG*` variables (`PGHOST`, `PGUSER`, `PGPASSWORD`) before the next step; Rails merges them over `config/database.yml`.

### 3. Set up the app

```bash
bin/setup
```

`bin/setup` is idempotent and does the following:

1. Installs gems (`bundle install`).
2. Enables the repository git hooks (`git config core.hooksPath .githooks`), which lint commit messages locally.
3. Prepares the databases (`bin/rails db:prepare`): creates `shango_development` and `shango_development_queue`, loads the schema and runs the seeds.
4. Clears old logs and temp files.
5. Starts the development server (`bin/dev`).

Useful flags:

| Command | Effect |
| --- | --- |
| `bin/setup --skip-server` | Set up without starting the server. |
| `bin/setup --reset` | Also run `bin/rails db:reset` (drops and recreates the development database). |

### 4. Run it

```bash
bin/dev
```

`bin/dev` starts [Foreman](https://github.com/ddollar/foreman) with `Procfile.dev`:

| Process | Command | Purpose |
| --- | --- | --- |
| `web` | `bin/rails server` | Puma web server. |
| `css` | `bin/rails tailwindcss:watch` | Rebuilds Tailwind CSS on change. |
| `jobs` | `bin/jobs` | Solid Queue worker. |

Open <http://localhost:3000>. Change the port with `PORT=3001 bin/dev` or by editing `.env`.

By default in development, API Client requests run **inline** in the web process, so the worker is optional for them. Set `SHANGO_EXECUTION_MODE=async` in `.env` to run them through the Solid Queue worker as production does. The worker is also what runs the recurring cleanup jobs.

Health endpoints: `/up` (the app booted) and `/ready` (booted and the database answers; 503 otherwise).

### 5. Create your account

Open the app, sign up, and create your first project (name and icon). You land in the workbench, where you can create a collection and send your first request. Email is off by default in development, so no confirmation step is required.

### Development seeds

`bin/rails db:seed` (also run by `db:setup` and `db:prepare` on a fresh database) loads `db/seeds/base/*.seeds.rb` in every environment, then `db/seeds/<environment>/*.seeds.rb` for the current one. Seeds are idempotent.

A **development account** exists for development only: `dev@shango.test` / `password`, with one project holding the public [Restful-Booker](https://restful-booker.herokuapp.com) API imported from its Postman collection and environment (`db/seeds/development/fixtures`), so the API Client can be tried against live requests. Rebuild it with `SEED_RESET=1 bin/rails db:seed`.

### Useful development commands

| Command | Purpose |
| --- | --- |
| `bin/dev` | Run web, CSS watcher and worker. |
| `bin/rails console` | Rails console. |
| `bin/rails db:migrate` | Run pending migrations. |
| `bin/rails db:reset` | Drop, recreate and re-seed the development database. |
| `bin/reset_db` | Rebuild every development database from the schema files and seed (`--no-seed` to skip seeding). |
| `bin/rails tailwindcss:build` | One-off Tailwind build (needed before running specs on a fresh checkout). |
| `bin/rails db:encryption:init` | Generate Active Record encryption keys. |
| `bin/ci` | Run the full local CI suite (see below). |

## Configuration

### Development

Development works without configuration. `.env` (loaded by `dotenv-rails`, git-ignored) may set `PORT` and `SHANGO_EXECUTION_MODE`; `.env.example` is the template:

```bash
cp .env.example .env
```

In development and test the Active Record encryption keys are derived from the app secret, so you do not need to generate any.

Never commit `.env` or any file containing secrets.

### Production environment variables

Full reference in [`docs/operations.md`](docs/operations.md) §2. The essentials:

**Required in production**

| Variable | Purpose |
| --- | --- |
| `SECRET_KEY_BASE` | Rails secret (sessions, signed cookies). |
| `SHANGO_DATABASE_PASSWORD` | PostgreSQL password for the `shango` user. |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Encryption of stored secrets; the app refuses to boot without them. Generate with `bin/rails db:encryption:init`. |
| `SHANGO_HOST` (and `SHANGO_PROTOCOL`, default `https`) | Host used in links inside emails. |

**Optional (selection)**

| Variable | Default | Purpose |
| --- | --- | --- |
| `SHANGO_BLOCK_PRIVATE_NETWORKS` | `true` in production | `false` lets API Client requests reach localhost and private networks. Every project member can then send requests from the server into your network; enable it only on trusted installs. |
| `SHANGO_EXECUTION_MODE` | `async` in production, `inline` elsewhere | Where API Client requests run. |
| `SHANGO_SMTP_ADDRESS` | unset | Turns email on (plus `SHANGO_SMTP_PORT`, `_USERNAME`, `_PASSWORD`, `_DOMAIN`, `_AUTHENTICATION`, `_STARTTLS` and `SHANGO_MAIL_FROM`). |
| `SHANGO_REQUIRE_EMAIL_CONFIRMATION` | `true` when SMTP is set | Force or skip email confirmation. |
| `SHANGO_STORAGE` | `local` | `s3` for S3-compatible storage (`SHANGO_S3_BUCKET`, `SHANGO_S3_REGION`, optional keys and endpoint). |
| `SHANGO_RATE_LIMIT_<NAME>` | see architecture §7 | `<count>/<seconds>` for `EXECUTIONS`, `OAUTH`, `IMPORTS`, `SIGN_IN`, `SIGN_UP`, `PASSWORD_RESET`. |
| `SHANGO_HISTORY_RETENTION_DAYS`, `SHANGO_NETWORK_HISTORY_RETENTION_DAYS` | 90 | Days before saved runs are deleted (`0` keeps them). |
| `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `JOB_CONCURRENCY` | 5, 1, 1 | Puma threads, Puma workers, Solid Queue worker processes. |

## Running the tests

Tests use RSpec. Create the test database once and build the CSS:

```bash
RAILS_ENV=test bin/rails db:create db:schema:load
bin/rails tailwindcss:build
```

Then:

```bash
bundle exec rspec                                              # everything (system specs need Chrome)
bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb" # what CI runs
bundle exec rspec spec/services/network                        # a subset
PARTIAL_RUN=1 bundle exec rspec path/to/file_spec.rb           # a subset without the coverage minimum
```

Rules:

- **Coverage must stay at 100%** (line and branch), enforced by SimpleCov over `app/`. The report goes to `coverage/` (git-ignored; override with `COVERAGE_DIR`).
- Every code change ships its specs in the same commit.
- Use the factories in `spec/factories`.
- Layout: `spec/models`, `spec/services`, `spec/components`, `spec/requests` (controllers and views), `spec/jobs`, `spec/mailers`, `spec/system` (browser smoke test), `spec/support`.
- External HTTP is stubbed with WebMock; specs never touch the network.
- JavaScript (Stimulus) has no unit tests yet.

## Code quality and CI

| Check | Command |
| --- | --- |
| Style | `bundle exec rubocop` (uses [`rubocop-kode`](https://github.com/Dach3r/rubocop-kode)) |
| Static security analysis | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` |
| Gem vulnerabilities | `bin/bundler-audit` |
| Importmap vulnerabilities | `bin/importmap audit` |
| Tests | `bundle exec rspec` |

`bin/ci` runs setup, all the checks above and the test suite in one go; run it before opening a pull request.

GitHub Actions (`.github/workflows/`):

- `ci.yml`: security, lint and test jobs on every pull request and on pushes to `main` (PostgreSQL 17 service).
- `commit_lint.yml`: validates every commit subject of a pull request.

Dependabot opens weekly updates for gems and Actions.

## Project structure

```
app/
  components/      ViewComponents (app/components/<name>/component.rb)
  controllers/     Thin controllers, grouped in feature modules (Workbench::, Network::, Projects::, Users::)
  javascript/      Stimulus controllers and small libraries (importmap)
  jobs/            Active Job classes (Solid Queue)
  models/          Active Record models (not namespaced)
  services/        Business logic (ApiClient::, Network::, Projects::, Users::), using Serviceable and Result
  views/           ERB templates
config/
  locales/         i18n files, one folder per language
  recurring.yml    Solid Queue recurring jobs
db/
  migrate/         Primary database migrations
  seeds/           base/ and <environment>/ seeds
docs/              Product, architecture, operations and feature documentation
lib/
  shango/          App-level helpers (encryption keys, storage, mailing, execution mode)
  tasks/           Rake tasks (encryption key rotation)
spec/              RSpec suite
```

Domain overview: `User` → `Membership` (role `owner` / `member`) → `Project`. Everything else (environments, variables, collections, folders, requests, executions, cookies, network runs) belongs to a project and is always queried through the current project. All tables use UUID primary keys. See [`docs/architecture.md`](docs/architecture.md) and [`docs/api-client.md`](docs/api-client.md).

## Conventions

The authoritative list is in [`CLAUDE.md`](CLAUDE.md) and [`docs/architecture.md`](docs/architecture.md); the highlights:

- **URLs** are in English, RESTful, with underscores instead of hyphens (`curl_import`).
- **Controllers** are thin, plural and REST-named, in feature modules; **business logic** goes in `app/services` using `Serviceable`.
- **i18n**: every user-facing string goes in both `en` and `es` locale files (default `en`); no hard-coded UI text. System-defined records keep an internal lowercase snake_case name and are translated for display.
- **Project scope**: all domain data belongs to a project and is queried through it.
- **Secrets** (tokens, credentials, sensitive variable values) use Active Record encryption, never plain columns, and are never logged or rendered back unmasked.
- **Migrations**: one `create_table` per migration named `create_<table>`; other changes get their own `add_<column>_to_<table>`; never edit a committed migration; timestamps come from the real creation moment.
- **Enums** are string-backed with a `CHECK` constraint.
- **UI style**: line design (square corners, hairline borders, no shadows).
- **Dependencies** must have AGPL-compatible licenses (MIT, BSD, Apache-2.0, LGPL; never GPL-2.0-only).
- **Commits**: gitmoji + Conventional Commits, `<emoji> <type>(<scope>): <subject>`, for example `✨ feat(api_client): add digest auth`. The format is enforced by `bin/lint_commit_message` (local `commit-msg` hook, installed by `bin/setup`) and by the `Commit lint` workflow. The emoji for each type:

  | Emoji | Type | Use |
  | --- | --- | --- |
  | ✨ | `feat` | new feature or behavior |
  | 🐛 | `fix` | bug fix |
  | ♻️ | `refactor` | restructure without behavior change |
  | ⚡️ | `perf` | performance |
  | 💄 | `style` | visual change only |
  | ✏️ | `copy` | wording and microcopy |
  | 🌐 | `i18n` | locale files and translations |
  | 🧪 | `test` | specs |
  | 📝 | `docs` | documentation |
  | 🔧 | `chore` | config and tooling |
  | 🙈 | `chore` | `.gitignore` |
  | 🔥 | `chore` / `refactor` | remove code or files |
  | 🔒 | `feat` / `fix` | security, privacy, encryption |
  | 🛡️ | `feat` / `fix` | abuse protection and rate limits |
  | 📦 | `build` | packaging and dependency bumps |
  | 👷 | `ci` | CI workflows |
  | 🚀 | `ci` / `chore` | deploy |
  | ⏪ | `revert` | revert |

- **Docs** live in `docs/`, are written in English, and a behavior change updates its document in the same commit.

## Deployment

Shango ships a production `Dockerfile` (Thruster in front of Puma, port 80). Summary; the full guide is [`docs/operations.md`](docs/operations.md).

### Running with Docker

The `Dockerfile` builds a **production** image (`RAILS_ENV=production`, multi-stage, assets precompiled, runs as a non-root user). It contains only the app: you provide PostgreSQL and the environment variables. The steps below run everything with plain `docker` commands.

**1. Build the image**

```bash
docker build -t shango .
```

**2. Create a network and a PostgreSQL container**

The app connects as the PostgreSQL role `shango` using `SHANGO_DATABASE_PASSWORD`, and creates its four databases on boot, so that role must exist and be allowed to create databases (the `POSTGRES_USER` of the official image is a superuser).

```bash
docker network create shango

docker run -d --name shango-db --network shango \
  -e POSTGRES_USER=shango \
  -e POSTGRES_PASSWORD=change-me \
  -v shango_pgdata:/var/lib/postgresql/data \
  postgres:17
```

**3. Generate secrets and write the env file**

```bash
openssl rand -hex 64        # value for SECRET_KEY_BASE
bin/rails db:encryption:init  # from a checkout; prints the three ACTIVE_RECORD_ENCRYPTION_* values
```

Create `.env.production` (never commit it):

```bash
SECRET_KEY_BASE=<generated>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<generated>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<generated>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<generated>
SHANGO_DATABASE_PASSWORD=change-me     # same value as POSTGRES_PASSWORD
SHANGO_HOST=shango.example.com
PGHOST=shango-db                       # name of the PostgreSQL container
```

`PGHOST` is read by the PostgreSQL client library, so it applies to all four databases. Keep the three encryption values somewhere safe: without them stored secrets cannot be decrypted (see [Backups and upkeep](#backups-and-upkeep)).

**4. Start the web container**

```bash
docker run -d --name shango-web --network shango \
  --env-file .env.production \
  -p 80:80 \
  -v shango_storage:/rails/storage \
  shango
```

On start the entrypoint runs `bin/rails db:prepare` (creates the databases and loads the schema on first run, migrates on later ones) and then boots Thruster + Puma on port 80. Check it:

```bash
docker logs -f shango-web
curl http://localhost/up        # booted
curl http://localhost/ready     # booted and the database answers
```

**5. Start the worker**

In the default `async` mode, API Client requests are executed by a Solid Queue worker. Run the same image with a different command:

```bash
docker run -d --name shango-worker --network shango \
  --env-file .env.production \
  -v shango_storage:/rails/storage \
  shango ./bin/jobs
```

On a small install you can skip this container and add `SOLID_QUEUE_IN_PUMA=true` to `.env.production` to run the worker inside the web process. Or set `SHANGO_EXECUTION_MODE=inline` to execute requests in the web request and need no worker (background cleanup jobs then do not run).

**6. Put TLS in front**

The app forces HTTPS and assumes a TLS-terminating reverse proxy (Caddy, Nginx, a cloud load balancer…) in front of port 80, and the session cookie is `Secure`. For a purely local trial, browsers that treat `localhost` as a secure context (Chrome, Firefox) work over plain HTTP; Safari does not keep `Secure` cookies on HTTP. Cap request body size at the proxy as well.

**Updating**

```bash
git pull
docker build -t shango .
docker rm -f shango-web shango-worker   # data lives in the volumes and in PostgreSQL
# re-run the web and worker commands from steps 4 and 5; migrations run on boot
```

**Useful commands**

```bash
docker exec -it shango-web ./bin/rails console
docker exec -it shango-web ./bin/rails db:migrate:status
docker exec shango-db pg_dump -U shango -Fc shango_production > shango_production.dump
```

> The image follows the standard Rails 8 pattern but has not been built in CI yet, and the steps above were written from the `Dockerfile` and `bin/docker-entrypoint`, not from a full end-to-end run. Report anything that does not work.

### Deployment notes

- **Processes**: one web process (the image default) and, in the default `async` execution mode, one Solid Queue worker (`bin/jobs`) as a second container, or `SOLID_QUEUE_IN_PUMA=true` to run it inside the web process on small installs. Without a worker, API Client requests never finish unless you set `SHANGO_EXECUTION_MODE=inline`.
- **Databases**: one PostgreSQL server with four databases (`shango_production`, `_cache`, `_queue`, `_cable`). The container entrypoint runs `bin/rails db:prepare` before the web server starts.
- **TLS**: the app forces SSL and expects a TLS-terminating proxy in front. Cap request body size at the proxy as well.
- **Storage**: uploaded request bodies live in `/rails/storage` (mount it as a volume) unless `SHANGO_STORAGE=s3`.
- **Probes**: `/up` and `/ready`.

## Backups and upkeep

- Dump the **primary** database (`pg_dump -Fc shango_production`) on a schedule; cache, queue and cable databases are disposable.
- Back up `/rails/storage` or the S3 bucket.
- **Keep the three `ACTIVE_RECORD_ENCRYPTION_*` values with the backup**, in a secrets manager and never next to the dump: without them every stored secret is unreadable.
- Recurring jobs (finished-job cleanup, orphaned upload purge, saved-response and Network Tools history retention) only run while a worker is up.
- Rotate encryption keys when someone with access leaves (`bin/rails shango:encryption:rotate`, see [`docs/api-client.md`](docs/api-client.md) §6).
- Keep dependencies current; ship stdout logs (they carry a request id) to your log platform. No error tracker is bundled.

Details and the restore procedure: [`docs/operations.md`](docs/operations.md) §3 and §4.

## Security

- Secrets are encrypted at rest with Active Record encryption and masked in the UI and logs.
- API Client and Network Tools block requests to localhost and private networks by default in production (SSRF protection); `SHANGO_BLOCK_PRIVATE_NETWORKS=false` opts out knowingly.
- Rate limits on sign-in, sign-up, password reset, executions, OAuth and imports; account lockout after repeated failed sign-ins; idle session timeout.
- Content Security Policy and other security headers are enabled.
- Every query is scoped to the current project.

More in [`docs/architecture.md`](docs/architecture.md) §7. If you find a vulnerability, please do not open a public issue; contact the maintainers privately.

## Documentation index

| Document | Read it when |
| --- | --- |
| [`docs/product.md`](docs/product.md) | Product vision, audience, principles, concepts, roadmap. Before any feature work. |
| [`docs/architecture.md`](docs/architecture.md) | Stack, domain model, subsystems, security, conventions. Before technical decisions. |
| [`docs/operations.md`](docs/operations.md) | Deployment, environment variables, backups, upkeep, seeds. Before touching config, jobs or deployment. |
| [`docs/api-client.md`](docs/api-client.md) | Collections, requests, environments, auth strategies, execution, CodeMirror vendoring. |
| [`docs/network-tools.md`](docs/network-tools.md) | DNS checker, port check, TCP ping: design, limits, security. |
| [`CLAUDE.md`](CLAUDE.md) | Working agreements for AI coding assistants in this repository. |

## Contributing

The full guide is in [`CONTRIBUTING.md`](CONTRIBUTING.md). In short:

1. Read [`docs/product.md`](docs/product.md) and [`docs/architecture.md`](docs/architecture.md), and check the real code before assuming a feature exists.
2. Stay inside the scope of the change; open an issue or ask before significant product or architecture changes.
3. Branch from `main`, run `bin/setup` once so the commit hooks are active.
4. Ship specs with the change (coverage stays at 100%) and update the matching document in `docs/`.
5. Run `bin/ci` before opening the pull request.
6. Follow the commit format described in [Conventions](#conventions).

Opening a pull request means you accept the AGPL-3.0 for your contribution and grant the maintainers the right to relicense it; there is nothing to sign (see [`CONTRIBUTING.md`](CONTRIBUTING.md#license-and-relicensing)).

## License

Shango is released under the [GNU Affero General Public License v3.0](LICENSE).
