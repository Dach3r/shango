# Shango — Architecture

> Technical reference for engineers. Product vision, audience, and roadmap live in [`product.md`](product.md). Sections marked **Target** describe intended design, not what exists today; always check the code for the real state.

## 1. Architectural goals

Derived from the product principles:

- **Easy to run and self-host** — clone, configure, run. No mandatory external services.
- **Modular monolith** — one deployable Rails app with clear internal module boundaries. No SPA, no microservices, no frontend/backend split without a concrete need.
- **Shared context** — tools reuse the same underlying records instead of duplicating configuration.
- **Secure by default** — secrets, SSH, and production data are protected from day one.
- **Extensible** — a new tool plugs into projects, environments, and incidents without reshaping the core.
- **Progressive complexity** — build infrastructure only when a feature needs it.

## 2. Technology stack

| Layer | Choice |
|-------|--------|
| Framework | Ruby on Rails 8.1 (MVC monolith) |
| Database | PostgreSQL |
| Views | ERB |
| Frontend | Hotwire (Turbo) + Stimulus |
| Styling | Tailwind CSS |
| UI components | ViewComponent |
| Authentication | Devise |
| Background jobs | Active Job + Solid Queue |
| Cache / Cable | Solid Cache / Solid Cable |
| Assets / JS | Propshaft + importmap |

Specialized interfaces may add JavaScript libraries (e.g. xterm.js for the terminal, a code editor for request bodies). These are starting decisions, not immutable constraints.

## 3. High-level structure

One deployable Rails app with two process types sharing one PostgreSQL database. External systems are only reached outbound from Shango and are never required to run it.

| Part | Responsibility |
|------|----------------|
| Web (Puma) | Serves HTML and Turbo Streams; controllers, ViewComponents/ERB, models |
| Workers (Solid Queue) | Scheduled monitor checks, notification delivery, long-running tasks |
| PostgreSQL | Single source of truth for application data, jobs, cache, and cable |
| External systems | Only reached outbound from Shango, never required to run it |

## 4. Domain model (Target)

Entities and ownership:

- A `User` owns many `Project`s.
- A `Project` owns its `Environment`s (with `Variable`s), `Service`s, `Server`s, `NotificationChannel`s, `Collection`s, `Monitor`s, and `ApiDocumentation`.
- A `Collection` contains nested `Folder`s, which contain `Request`s.
- A `Monitor` references a `Request`, runs in an `Environment`, optionally targets a `Service`, and records many `CheckResult`s and `Incident`s.
- An `Incident` can start many `Investigation`s (AI-assisted).
- A `Server` optionally belongs to an `Environment`.
- `ApiDocumentation` is derived from `Request`s.

Rules:

- **`Project` is the tenancy boundary.** Every project-owned record reaches its project, and every query is scoped through it. Cross-project access must be impossible by construction (scoped associations, not ad hoc `where` clauses).
- **Reuse over duplication.** A `Monitor` references a `Request`; it does not copy URL, method, headers, or body. `ApiDocumentation` is derived from requests and extended manually.
- **Variables resolve at execution time.** `{{name}}` references in requests, monitors, and servers are interpolated from the selected `Environment` when run.

## 5. Application conventions

Existing, to be followed:

- Controllers behind login inherit `AuthenticatedController` (`before_action :authenticate_user!`).
- UI components live in `app/components/<name>/component.rb` (with an optional `component.html.erb`) and inherit `ApplicationComponent`, e.g. `Button::Component`.
- Stimulus controllers in `app/javascript/controllers/`, named `<name>_controller.js`.
- Tailwind with a `brand-*` color palette.
- Lint with rubocop (`rubocop-kode`); security checks with brakeman and bundler-audit.

## 6. Key subsystems (Target)

### API Client execution

Requests run server-side: resolve environment variables, build the HTTP call, execute with timeout limits, store/return the response. Results stream back to the UI via Turbo. Outbound calls must guard against abuse (timeouts, size limits, and an SSRF policy suited to the deployment mode, since self-hosted users legitimately target private addresses).

### Monitoring

A scheduler enqueues check jobs per monitor at its interval (Solid Queue recurring tasks or a dispatcher job). Each check executes the referenced request, evaluates success/failure conditions, and writes a `CheckResult`. State transitions (up → down, down → up) open or resolve an `Incident` and emit notification events. Notification dispatch is deduplicated to avoid repeated alerts.

### Notifications

A channel abstraction (email, webhook first; Slack/Discord later) behind a common delivery interface, fed by domain events (incident opened, recovered). Delivery runs in background jobs with retries.

### SSH and terminal

Browser terminal (xterm.js) connected over WebSocket (Action Cable) to a server-side SSH session. Sessions are explicit, authorized per user and server, time-limited, and audited. Private keys are never sent to the browser.

### AI assistant

A provider-agnostic adapter layer (commercial providers, user-configured models, BYOK, possibly local models). Context is assembled from explicitly authorized project data (requests, responses, monitors, incidents, logs). Tool access is tiered: read-only first; any action with side effects requires permission checks and explicit user confirmation. Responses separate evidence from hypotheses.

## 7. Security architecture

- **Secrets** (environment variables flagged sensitive, tokens, SSH keys, AI provider keys): encrypted at rest (Rails Active Record Encryption is the default candidate), masked in the UI, excluded from logs (`filter_parameters`), and never included in AI context without explicit authorization.
- **Authorization:** all project resources scoped to the current user's projects.
- **SSH:** no unauthenticated or unscoped connections; session lifetime limits; audit trail.
- **AI:** read-only by default; confirmation gates for sensitive actions.
- **Self-hosted:** data stays on the operator's infrastructure; configuration through environment variables (`.env` in development).

## 8. Deployment

- **Self-hosted (primary):** run web + Solid Queue against a PostgreSQL instance. The repo ships `Procfile.dev` for local development (`web`, `css`) and uses Thruster/Puma for production.
- **Cloud (future):** may require connectors, tunnels, or agents to reach private networks. Not designed yet; do not build for it now.

## 9. Current state (snapshot)

- Authentication (Devise, `User` with first/last name).
- Memberships link users to projects with a `role` (`owner`/`member`) and a nullable `revoked_at`: a revoked membership is kept as history and no longer grants access. The unique `(user_id, project_id)` index is partial (`revoked_at IS NULL`), so a user can be re-added later. `User#projects`, `Project#users` and `User#available_memberships` only consider active memberships.
- Current selection: `users.current_membership_id` (nullable FK, `nullify` on delete). `AuthenticatedController#current_membership` returns it while it is active and its project not archived, otherwise falls back to the oldest available membership and persists it; `current_project` derives from it and `current_membership.role` is available to the UI. `CurrentProjectsController#update` switches it. Creating a project selects its owner membership.
- Authenticated layout (`layouts/app`): sidebar (`Sidebar`, `ProjectSwitcher`, `NavItem`) + topbar (`Topbar`, `UserMenu` with theme/locale switchers and sign out). Below `lg` the sidebar is an off-canvas drawer (`drawer` Stimulus controller); menus use the `dropdown` controller. Nav entries without a route render disabled with a "Soon" badge; enable each as its feature lands. `/` is `OverviewController#show`; guests are redirected to sign in by `authenticate_user!`.
- `Project` and `Membership` (role `owner`/`member`). `AuthenticatedController#require_project` redirects any user without an active project to `projects#new`, so every user creates a first project (name + icon) right after sign-up. `Project.create_with_owner` creates the project and its owner membership in one transaction.
- Shared UI components (`Button`, `Input`, `Link`, `Logo`, `ThemeSwitcher`, `LocaleSwitcher`) and Stimulus controllers for password visibility, icon picking, dropdowns and the drawer.
- PostgreSQL schema contains `users`, `projects`, `memberships` and Active Storage tables; the `uuid-ossp` extension is enabled.
- No tests or other domain models yet.

Update this section as features land.

## 10. Open technical questions

- Primary key strategy: the `uuid-ossp` extension is enabled but the current schema uses default integer ids.
- Secret storage and key management for self-hosted installs.
- Scheduler design for monitors and check-result retention policy.
- Team model: sharing, roles, and permissions within a project (affects authorization design).
- Log ingestion: pull over SSH, push via agent/webhook, or integrations.
- Private-network access for a future cloud offering.

## 11. Engineering guidelines

1. Review the real code and conventions before adding anything.
2. Reuse existing records and components; avoid duplicating configuration or business logic.
3. Avoid unnecessary architecture and infrastructure.
4. Keep project scoping and secret handling in mind for every new model.
5. Stay within the requested scope; ask before changes that significantly alter architecture.
