# Shango

Open source Developer Workspace (Rails 8.1 monolith, PostgreSQL, ERB, Hotwire/Turbo, Stimulus, Tailwind, ViewComponent, Solid Queue).

## Documentation

All documentation in `docs/` **must be written in English**.

Consult when you need context:

- `docs/product.md` — product vision, audience, principles, concepts, roadmap (product owner / manager view). Read before any feature work.
- `docs/architecture.md` — stack, domain model, subsystems, security, conventions, open technical questions. Read before technical or architectural decisions.
- `docs/operations.md` — deployment, environment variables, backups, upkeep, known gaps. Read before touching config, jobs, deployment or env vars.
- `docs/api-client.md` — API Client (collections, requests, environments, auth strategies, execution, security, CodeMirror vendoring). Read before touching that feature.
- `docs/network-tools.md` — Network Tools (DNS checker, port check, TCP ping): design, limits, security, how it was built. Read before touching that feature; never add nmap (license, see that doc §2).

Add new docs under `docs/` and reference them here.

## Ground rules

- Distinguish vision vs roadmap vs actual repo state. Check the real code before assuming a feature exists.
- Stay in the requested scope; ask before significant product or architecture changes.
- Follow existing conventions (components in `app/components/<name>/component.rb`, rubocop-kode).
- Controllers go in feature modules with plural REST names and stay thin; business logic goes in `app/services` using `Serviceable`. Models are not namespaced.

## Conventions

- **URLs always in English**, REST resources whenever possible. Multi-word paths use underscores, never hyphens (`curl_import`). Static pages: `get :privacy, to: "pages#privacy"` (no redundant `as:`; use `as:` only when name differs from path). Nested actions live in their own controller (`resource :position, module: :requests`).
- **Internal names**: system-defined records (roles, kinds, statuses) keep an internal `name`/value in lowercase snake_case English; display text always via i18n, never stored in DB. User-created records (projects, environments, collections, requests) store the name the user typed.
- **i18n**: every user-facing string goes in both `en` and `es` locale files (default `en`); no hard-coded UI text.
- **Project scope**: all domain data belongs to a project and must be queried through it (current project/membership). Data from one project never leaks into another.
- **Authorization**: Pundit policies in `app/policies`, subject is the current membership. Every action of an `AuthenticatedController` must `authorize` (or `skip_authorization` for the member's own state); owners manage everything, members only what they created (`creator_id`). Hide UI a member cannot use with `policy(record)`. See `docs/architecture.md` §7.
- **Secrets**: tokens, credentials, and sensitive variable values use Active Record encryption, never plain columns, and are never logged or rendered back unmasked.
- **UI style**: line design (square corners, hairline borders, no shadows); see `docs/architecture.md` §5.
- **Navigation**: never show unbuilt features as available; unbuilt nav entries render disabled with a "Soon" badge.
- **One `create_table` per migration file**, named `create_<table>`, ordered so referenced tables come first. Other schema changes get their own `add_<column>_to_<table>` migration; never bundle unrelated changes. **Migration timestamps look real**: use the actual moment you create it (`date +%Y%m%d%H%M%S`, e.g. `20261014143752`), never round or placeholder values like `...090000` or `...130000`, and keep them after the latest existing migration. Never edit a migration that is already committed; add a new one.
- **Enums are string-backed**, never integer: `enum :http_method, { get: "get", ... }` with `t.string ..., default: "<value>"`, plus a `CHECK` constraint in the migration.
- Commits: gitmoji + Conventional Commits (`<emoji> <type>(<scope>): <subject>`, e.g. `✨ feat(api_client): ...`), via the `commit` skill. No `Co-Authored-By` trailer. One emoji per case, always the same:
  - `✨ feat` new feature or behavior · `🐛 fix` bug fix · `♻️ refactor` restructure without behavior change · `⚡️ perf` performance
  - `💄 style` visual change only (CSS, layout, spacing, UI polish) · `✏️ copy` wording and microcopy · `🌐 i18n` locale files and translations
  - `🧪 test` add or change specs, including system and e2e specs (never `✅`)
  - `📝 docs` documentation · `🔧 chore` config and tooling · `🙈 chore` `.gitignore` · `🔥 chore`/`refactor` remove code or files
  - `🔒 feat`/`fix` security, privacy, encryption · `🛡️ feat`/`fix` abuse protection and rate limits
  - `📦 build` packaging and dependency bumps (`📦 build(deps)`, Dependabot included, never `⬆️`) · `👷 ci` CI workflows · `🚀 ci`/`chore` deploy · `⏪ revert`
- Format is enforced by `bin/lint_commit_message` (local `commit-msg` hook via `bin/setup`, and the `Commit lint` workflow on PRs); update its emoji list when adding a type here.
- **Auto-commit**: after every important change (feature, fix, refactor, migration, config/docs update) commit automatically without asking. Stage only files of that change (no `git add -A`, other WIP stays untouched), one logical commit per change, run `bundle exec rubocop` on touched files first. Never push, never amend, never commit `.env` or secrets.
- Keep code comment density low, match surrounding style.
- **Tests**: RSpec, `bundle exec rspec`; coverage must stay at 100% (line and branch, enforced by SimpleCov). Every code change ships its specs in the same commit; use factories from `spec/factories`.
- **License**: AGPL-3.0 (`LICENSE`, see `docs/product.md` §13). Only add dependencies with AGPL-compatible licenses (MIT, BSD, Apache-2.0, LGPL; never GPL-2.0-only). External contributions need no signed CLA: opening a pull request accepts the AGPL-3.0 and grants the maintainers the right to relicense the contribution (terms in `CONTRIBUTING.md`).
- **Docs**: a behavior change updates its document in `docs/` in the same commit. Docs and CLAUDE.md are in English.
