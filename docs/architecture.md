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
- A `Collection` contains nested `Folder`s, which contain `Request`s (the model is named `ApiRequest`; each run is stored as a `RequestExecution`).
- A `Monitor` references a `Request`, runs in an `Environment`, optionally targets a `Service`, and records many `CheckResult`s and `Incident`s.
- An `Incident` can start many `Investigation`s (AI-assisted).
- A `Server` optionally belongs to an `Environment`.
- `ApiDocumentation` is derived from `Request`s.

Rules:

- **`Project` is the tenancy boundary.** Every project-owned record reaches its project, and every query is scoped through it. Cross-project access must be impossible by construction (scoped associations, not ad hoc `where` clauses).
- **Selected environment.** `Membership#current_environment_id` stores the environment each member works with in a project.
- **Reuse over duplication.** A `Monitor` references a `Request`; it does not copy URL, method, headers, or body. `ApiDocumentation` is derived from requests and extended manually.
- **Variables resolve at execution time.** `{{name}}` references in requests, monitors, and servers are interpolated from the selected `Environment` when run.

## 5. Application conventions

Existing, to be followed:

- Controllers behind login inherit `AuthenticatedController` (`before_action :authenticate_user!`).
- Controllers are grouped in **feature modules** (`Workbench::`, `Projects::`, later `Documentation::`, `Monitoring::`…), use plural REST names (`Workbench::RequestsController`), and stay thin: they scope records through `current_project`, declare strong parameters and delegate to a service. Models stay flat (not namespaced). Each feature module has a `BaseController`.
- Business logic lives in `app/services/<feature>/<resource>/<action>.rb`, built on `Serviceable` (`Klass.call(**kwargs)` runs the private `perform`) and returning a `Result` (`app/services/result.rb`). Plain collaborators (resolvers, clients) are ordinary classes next to them.
- UI components live in `app/components/<name>/component.rb` (with an optional `component.html.erb`) and inherit `ApplicationComponent`, e.g. `Button::Component`.
- Stimulus controllers in `app/javascript/controllers/`, named `<name>_controller.js`. Third-party JS is vendored in `vendor/javascript` and pinned in `config/importmap.rb` (see [`api-client.md`](api-client.md) §7 for CodeMirror).
- Compact form controls for editor-style screens come from `ControlsHelper`; internal lookups inside ViewComponents call `I18n.t` in `initialize` (`t` only works while rendering).
- Translations live in `config/locales/*.{en,es}.yml`; every new key needs both languages. Inside a `render layout: ... do` block use absolute keys (lazy `t(".key")` resolves against the layout partial).
- Tailwind with a `brand-*` color palette.
- Lint with rubocop (`rubocop-kode`); security checks with brakeman and bundler-audit.

## 6. Key subsystems (Target)

### API Client execution

Requests run server-side and synchronously inside the web request: `ApiClient::RequestBuilder` resolves environment variables and authentication, `ApiClient::Executor` performs the call with Faraday (timeout, 5 MB read limit, redirect handling with per-hop SSRF checks), and `ApiClient::Requests::Run` stores a `RequestExecution` with secrets masked. The result is streamed back to the UI as a Turbo Stream. Details, auth strategies and limits: [`api-client.md`](api-client.md).

### Monitoring

A scheduler enqueues check jobs per monitor at its interval (Solid Queue recurring tasks or a dispatcher job). Each check executes the referenced request, evaluates success/failure conditions, and writes a `CheckResult`. State transitions (up → down, down → up) open or resolve an `Incident` and emit notification events. Notification dispatch is deduplicated to avoid repeated alerts.

### Notifications

A channel abstraction (email, webhook first; Slack/Discord later) behind a common delivery interface, fed by domain events (incident opened, recovered). Delivery runs in background jobs with retries.

### SSH and terminal

Browser terminal (xterm.js) connected over WebSocket (Action Cable) to a server-side SSH session. Sessions are explicit, authorized per user and server, time-limited, and audited. Private keys are never sent to the browser.

### AI assistant

A provider-agnostic adapter layer (commercial providers, user-configured models, BYOK, possibly local models). Context is assembled from explicitly authorized project data (requests, responses, monitors, incidents, logs). Tool access is tiered: read-only first; any action with side effects requires permission checks and explicit user confirmation. Responses separate evidence from hypotheses.

## 7. Security architecture

- **Secrets** (environment variables, request credentials and OAuth tokens today; SSH keys and AI provider keys later): encrypted at rest with Active Record Encryption, masked in the UI and in stored request/response history, excluded from logs (`filter_parameters`), and never included in AI context without explicit authorization. Keys come from `ACTIVE_RECORD_ENCRYPTION_*` environment variables or, when unset, are derived from `secret_key_base` (see [`api-client.md`](api-client.md) §6).
- **Outbound requests:** opt-in private-network blocking (`SHANGO_BLOCK_PRIVATE_NETWORKS=true`) for shared or cloud deployments.
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
- Per-membership settings live on `Membership` and are edited at `/membership/settings` (`Projects::MembershipsController`, user menu *Settings* item). Settings screens share a second navigation column (`SettingsNav::Component`) grouped by scope (*My account*, *<project> · my membership*, *Project*); only sections with a path are live, the rest render disabled with a *Soon* badge, so new settings screens add an entry there: `folder_toggle` (default `double_click`) decides how the API Client tree expands and collapses collections and folders, and `request_open` (default `click`) how it opens requests; both take `click`/`double_click`. Account-level data lives in Devise `registrations#edit`, served at `/users/settings` (`path_names: { edit: "settings" }`) inside the same settings shell (`settings/_shell`): `?tab=profile` (default; first name, last name, email), `?tab=preferences` (theme and language switchers, which PATCH `/preferences` and come back to the tab) and `?tab=security` (password, cancel account), whitelisted in `Users::RegistrationsController::TABS`; the *Profile*, *Preferences* and *Security* entries of `SettingsNav` point at them and the form keeps the tab on submit and redirect.
- Current selection: `users.current_membership_id` (nullable FK, `nullify` on delete). `ProjectContext#current_membership` (shared by `AuthenticatedController` and `Users::RegistrationsController`) returns it while it is active and its project not archived, otherwise falls back to the oldest available membership and persists it; `current_project` derives from it and `current_membership.role` is available to the UI. `CurrentProjectsController#update` switches it. Creating a project selects its owner membership.
- Authenticated layout (`layouts/app`): sidebar (`Sidebar`, `ProjectSwitcher`, `NavItem`) + bottom status bar (`StatusBar`: request breadcrumb and name on request pages, environment switcher; `UserMenu` is a dropdown in the sidebar footer opening upward with profile, *Settings* and sign out). Below `lg` the sidebar is an off-canvas drawer (`drawer` Stimulus controller); from `lg` up it collapses to an icon rail (`sidebar` Stimulus controller, state kept in the `sidebar_collapsed` cookie and read server-side by `SidebarState`, so there is no flash on load; collapsed styles hang off `group/sidebar` + `data-collapsed` on the layout wrapper); menus use the `dropdown` controller. Nav entries without a route render disabled with a "Soon" badge; enable each as its feature lands. The active entry is a tinted accent pill, available tools come first and the unbuilt ones follow under a *Coming soon* label (a hairline when collapsed; each one carries a *Soon* tooltip), and the collapsed rail shows square 40px icon buttons with the project as a plain tile. `/` is the sign in page (`devise/sessions#new`) for guests and redirects to the workbench (`Workbench::WorkspacesController#show`) for signed-in users; other guest requests are redirected to sign in by `authenticate_user!`.
- `Project` and `Membership` (role `owner`/`member`). `ProjectContext#require_project` redirects any user without an active project to `projects#new`, so every user creates a first project (name + icon) right after sign-up. `Project.create_with_owner` creates the project and its owner membership in one transaction.
- Destructive confirmations: any `data-turbo-confirm` is routed through `ConfirmDialog` (one `<dialog>` in `layouts/application`, `confirm-dialog` Stimulus controller overriding `Turbo.config.forms.confirm`) instead of the native browser `confirm`.
- Shared UI components (`Button`, `Input`, `Link`, `Logo`, `ThemeSwitcher`, `LocaleSwitcher`) and Stimulus controllers for password visibility, icon picking, dropdowns and the drawer.
- PostgreSQL schema contains `users`, `projects`, `memberships` and Active Storage tables; the `uuid-ossp` extension is enabled.
- **API Client** (phase 2): `Environment`/`Variable` (secrets encrypted, selected per membership from the top bar), `Collection`, `Folder`, `ApiRequest`, `RequestExecution`; request editor with CodeMirror, history, cURL import/copy, drag and drop tree, authorization per request or folder with inheritance (None, Basic, Bearer, API key, JWT, Digest, AWS SigV4, OAuth 2.0). See [`api-client.md`](api-client.md). Sidebar entries *API Client* and *Environments* are live.
- Controllers for the feature live in `Workbench::` and `Projects::` modules; logic is in `app/services` (`ApiClient::` namespace) (`Serviceable` + `Result`).
- Gems added: `faraday`, `faraday-multipart`, `jwt`, `aws-sigv4`, `net-http-digest_auth`.
- Tests: RSpec (`spec/`) with FactoryBot, shoulda-matchers, WebMock and ViewComponent test helpers. Run `bundle exec rspec`; SimpleCov enforces 100% line and branch coverage over `app/` (report in `coverage/`, git-ignored). Layout: `spec/models`, `spec/services`, `spec/components`, `spec/requests` (controllers and views), `spec/support`, `spec/factories`. Set `PARTIAL_RUN=1` to run a subset without the minimum check, and `COVERAGE_DIR` to redirect the report. JavaScript (Stimulus) is not covered.

Update this section as features land.

## 10. Open technical questions

- Key management for self-hosted installs: encryption keys default to values derived from `secret_key_base`; a rotation procedure is not defined.
- JavaScript tests (Stimulus controllers) and system/browser specs are not set up.
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
