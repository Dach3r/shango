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
- **UI is "line design"**: square corners (no `rounded-*` except `rounded-full` on dots and spinners), 1px `border-line` hairlines instead of fills and shadows, hairline `ring-1` focus, active nav marked by a left accent border and tabs by an underline, mono uppercase for section labels. Colors always come from palette tokens.
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

### Network tools

DNS checker, port check and TCP ping, run synchronously in the web request with hard caps (ports, timeouts, concurrency) and no persistence. Built on the Ruby standard library (`Resolv::DNS`, `Socket`); nmap is excluded for license reasons. Targets are checked with the same SSRF policy as the API Client and rate limited per user. Details, limits and implementation plan: [`network-tools.md`](network-tools.md).

### SSH and terminal

Browser terminal (xterm.js) connected over WebSocket (Action Cable) to a server-side SSH session. Sessions are explicit, authorized per user and server, time-limited, and audited. Private keys are never sent to the browser.

### AI assistant

A provider-agnostic adapter layer (commercial providers, user-configured models, BYOK, possibly local models). Context is assembled from explicitly authorized project data (requests, responses, monitors, incidents, logs). Tool access is tiered: read-only first; any action with side effects requires permission checks and explicit user confirmation. Responses separate evidence from hypotheses.

## 7. Security architecture

- **Secrets** (environment variables, request credentials and OAuth tokens today; SSH keys and AI provider keys later): encrypted at rest with Active Record Encryption, masked in the UI and in stored request/response history, excluded from logs (`filter_parameters`), and never included in AI context without explicit authorization. Keys come from `ACTIVE_RECORD_ENCRYPTION_*` environment variables, which production requires; dev and test derive them from `secret_key_base`. Rotation is a documented procedure with a rake task (see [`api-client.md`](api-client.md) §6).
- **Outbound requests:** private-network blocking is on by default in production; each operator decides with `SHANGO_BLOCK_PRIVATE_NETWORKS=true|false` (see [`api-client.md`](api-client.md) §6).
- **Network tools:** port check and TCP ping reuse the outbound-request guard and pin the connection to the checked address; DNS queries only go to fixed public resolvers and to authoritative nameservers that also pass the guard; one host per run, connect-only probes, per-user rate limit, audit log line per run (see [`network-tools.md`](network-tools.md) §6).
- **Content Security Policy** (`config/initializers/content_security_policy.rb`): `default-src 'self'`, scripts from `'self'` plus a per-request nonce (the importmap tag carries it; no inline scripts or `on*` handlers may be added), inline styles allowed (CodeMirror injects `<style>`, and srcdoc response previews inherit the policy), Google Fonts allowed for CSS/fonts, `img-src` self/data/blob/https, `connect-src 'self'` (Turbo, fetch, Action Cable), `object-src 'none'`, `base-uri 'self'`, `frame-ancestors 'none'`. `form-action` is deliberately not set because Chrome enforces it on redirects and would break the OAuth 2.0 authorization redirect. `SHANGO_CSP_REPORT_ONLY=true` reports violations in the browser console without blocking, useful when adding third-party assets. Other headers: Rails defaults (`X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`) plus a restrictive `Permissions-Policy` (`config/initializers/security_headers.rb`).
- **Accounts:** Devise `lockable` (10 failed sign-ins lock the account for 30 minutes; `SHANGO_MAX_SIGN_IN_ATTEMPTS`; email unlock too when SMTP is set), `timeoutable` (idle sessions expire after 12 h; `SHANGO_SESSION_TIMEOUT_HOURS`) and `paranoid` mode (reset and confirmation forms answer the same for unknown emails). Cancelling an account (`DELETE /users`, `Users::Destroy`) asks for the current password; projects where the user is the only member are deleted with the account, and the cancellation is refused while the user is the only owner of a project that still has other members (it would be left without an owner).
- **Email is optional.** `Shango::Mailing` (`lib/shango/mailing.rb`) turns email features on only when `SHANGO_SMTP_ADDRESS` is set. Configure it with `SHANGO_SMTP_ADDRESS`, `SHANGO_SMTP_PORT` (587), `SHANGO_SMTP_USERNAME`, `SHANGO_SMTP_PASSWORD`, `SHANGO_SMTP_DOMAIN`, `SHANGO_SMTP_AUTHENTICATION` (plain), `SHANGO_SMTP_STARTTLS` (true), `SHANGO_MAIL_FROM` and `SHANGO_HOST`/`SHANGO_PROTOCOL` (links in emails). Without SMTP: accounts are active immediately, password reset, confirmation and unlock screens are unavailable (their links are hidden and the routes redirect to sign in with a notice), and email changes apply directly. With SMTP: password reset works and new accounts must confirm their email before signing in, unless the operator sets `SHANGO_REQUIRE_EMAIL_CONFIRMATION=false` (mail stays on, confirmation is not enforced). Users that existed before confirmation shipped are backfilled as confirmed.
- **Rate limiting:** the `Throttling` concern (`throttle :name, by:`) counts requests per user (or IP when signed out) in `Rails.cache` and answers 429-style: a redirect with a flash alert, or a Turbo Stream error in the response panel for executions. Defaults: executions 60/min, OAuth 20/min, imports 10/10 min, sign in 10/min, sign up 10/h, password reset 5/h. Operators override any of them with `SHANGO_RATE_LIMIT_<NAME>=<count>/<seconds>` (`EXECUTIONS`, `OAUTH`, `IMPORTS`, `SIGN_IN`, `SIGN_UP`, `PASSWORD_RESET`). Devise controllers are wired in `config/initializers/throttling.rb`. Counters live in the shared cache (Solid Cache), so they hold across processes; the test environment uses a null store, so specs swap in a memory store.
- **Authorization:** all project resources scoped to the current user's projects. Roles (`owner`/`member`) are not enforced yet; tracked as a non-blocking gap in [`operations.md`](operations.md) §5.
- **SSH:** no unauthenticated or unscoped connections; session lifetime limits; audit trail.
- **AI:** read-only by default; confirmation gates for sensitive actions.
- **Self-hosted:** data stays on the operator's infrastructure; configuration through environment variables (`.env` in development).

## 8. Deployment

- **Web concurrency:** Puma runs `RAILS_MAX_THREADS` threads (default 5, also the database pool size per process) and, when `WEB_CONCURRENCY` is greater than 1, that many preloaded worker processes. Requests sent from the API Client run in a background job by default in production (`SHANGO_EXECUTION_MODE=async`, see [`api-client.md`](api-client.md) §4), so slow targets cannot hold web threads; that needs a Solid Queue worker (`bin/jobs`, or `SOLID_QUEUE_IN_PUMA=true` to run it inside Puma). `SHANGO_EXECUTION_MODE=inline` (the default in development and test) runs them in the web request instead (bounded by the 120 s total deadline and the rate limits); size threads and workers accordingly. Health probes: `/up` (the app booted) and `/ready` (also needs the database; 503 otherwise).
- **File storage:** uploads (request bodies) use Active Storage; `SHANGO_STORAGE=local` (default, the `storage/` directory, single app server only) or `SHANGO_STORAGE=s3` with `SHANGO_S3_BUCKET`, `SHANGO_S3_REGION`, optional `SHANGO_S3_ACCESS_KEY_ID`/`SHANGO_S3_SECRET_ACCESS_KEY` (otherwise the AWS SDK credential chain, e.g. an instance role) and `SHANGO_S3_ENDPOINT` for S3-compatible stores such as MinIO or R2. `PurgeOrphanedBlobsJob` (recurring, daily) purges blobs unattached for more than 2 days.
- **Self-hosted (primary):** run web + Solid Queue against a PostgreSQL instance. The repo ships `Procfile.dev` for local development (`web`, `css`, `jobs`: the Solid Queue worker `bin/jobs`, backed by its own `shango_development_queue` database that `bin/rails db:prepare` creates) and uses Thruster/Puma for production.
- **Operations:** image, processes, environment reference, backups and upkeep are in [`operations.md`](operations.md).
- **Cloud (future):** may require connectors, tunnels, or agents to reach private networks. Not designed yet; do not build for it now.

## 9. Current state (snapshot)

- Authentication (Devise, `User` with first/last name).
- Memberships link users to projects with a `role` (`owner`/`member`) and a nullable `revoked_at`: a revoked membership is kept as history and no longer grants access. The unique `(user_id, project_id)` index is partial (`revoked_at IS NULL`), so a user can be re-added later. `memberships_role_check` (like the other string enums) enforces `owner`/`member` in the database, and the preference enums use `validate: true`, so an unknown `theme`, `color_scheme`, `folder_toggle` or `request_open` answers `422` instead of raising. `User#projects`, `Project#users` and `User#available_memberships` only consider active memberships.
- Per-membership settings live on `Membership` and are edited at `/membership/settings` (`Projects::MembershipsController`, user menu *Settings* item). Settings screens share a second navigation column (`SettingsNav::Component`) grouped by scope (*My account*: Profile, Security, Cancel account; *Appearance*: Preferences, Themes, Sidebar; *Project*); only sections with a path are live, the rest render disabled with a *Soon* badge, so new settings screens add an entry there: `folder_toggle` (default `double_click`) decides how the API Client tree expands and collapses collections and folders, and `request_open` (default `click`) how it opens requests; both take `click`/`double_click`; `collapse_nested_folders` (boolean, default `true`) decides whether closing a collection or folder also closes the folders inside it. `color_scheme` (`system`/`light`/`dark`, default `system`) and `theme` (palette: accent variants such as `blue` or `ocean` and surface themes such as `nord`, `dracula`, `gruvbox`, `solarized`, `cyberpunk`; the full list is `Membership::THEMES`) are edited at `/theme/settings` (`Projects::ThemesController`, *Themes* entry in `SettingsNav`) with skeleton previews (`ThemePreview::Component`); picking a color scheme or palette previews it and submits the form right away (`theme-preview` Stimulus controller), so there is no save button; `Theming#current_theme`/`current_palette` read them for signed-in members and set `data-theme`/`data-palette` on `<html>`, while public pages keep the `theme` cookie. Palettes only override tokens in `application.css` (`[data-palette=...]`), so new ones also need an entry in `Membership::THEMES` and the `memberships_theme_check` constraint. Account-level data lives in Devise `registrations#edit`, served at `/users/settings` (`path_names: { edit: "settings" }`) inside the same settings shell (`settings/_shell`): `?tab=profile` (default; first name, last name, email), `?tab=preferences` (language switcher and zoom picker, which PATCH `/preferences` and come back to the tab; zoom is a single connected segmented bar (radios, equal-width cells with hairline dividers, a small accent dot marks the default step) of 75–200 % in the `zoom` cookie, default 95, validated by `Zooming`, applied as `data-zoom` on `<html>` (guest Devise pages such as sign in and sign up always use 100 %) which sets the root font size so rem-based sizes scale, and previewed instantly by the `zoom` Stimulus controller; UI sizes must therefore be rem, never px, including the CodeMirror theme and arbitrary Tailwind values — only 1–2px hairlines and positioning math stay px, enforced by `spec/lib/rem_sizing_spec.rb`) `?tab=security` (password) and `?tab=delete_account` (cancel account, its own sidebar entry), whitelisted in `Users::RegistrationsController::TABS`; the *Profile*, *Preferences*, *Security* and *Cancel account* entries of `SettingsNav` point at them and the form keeps the tab on submit and redirect.
- Current selection: `users.current_membership_id` (nullable FK, `nullify` on delete). `ProjectContext#current_membership` (shared by `AuthenticatedController` and `Users::RegistrationsController`) returns it while it is active and its project not archived, otherwise falls back to the oldest available membership and persists it; `current_project` derives from it and `current_membership.role` is available to the UI. `CurrentProjectsController#update` switches it. Creating a project selects its owner membership.
- Authenticated layout (`layouts/app`): no top bar, only a `sticky` bottom status bar 2.5rem tall (`StatusBar`: request breadcrumb and name on request pages, then at the right the environment switcher, `ProjectSwitcher` and `UserMenu`; screens that fill the viewport use `100vh - 2.5rem`). `ProjectSwitcher` is a compact trigger (icon, name, chevron; below `sm` only the icon) whose menu opens upward; menus use the `dropdown` controller. `UserMenu` is the initials avatar and opens the right sidebar with `/account` (clicking it again closes it) (`Users::AccountsController#show`): the project tools (`ToolsNav`: available ones are links, unbuilt ones render disabled with a *Soon* badge, enable each as its feature lands), the profile card, *Settings* and sign out. The layout also has a right sidebar (`right-sidebar` Stimulus controller, hidden by default; a fixed overlay below `lg`, a third grid column from `lg` up) holding the `right_sidebar` Turbo Frame: links with `data-turbo-frame="right_sidebar"` and `data-action="right-sidebar#open"` (plus a `right_sidebar_title_param`) load into it, today *Manage environments* from the environment switcher and the account panel from the user menu (the environments index, new and edit pages are side-panel only: outside a frame request they redirect to the workbench, and the left sidebar has no entry for them). Views meant for it wrap their content in `projects/environments/panel`-style layouts that emit the frame only on frame requests, so the same pages still work as full pages. `/` is the sign in page (`devise/sessions#new`) for guests and redirects to the workbench (`Workbench::WorkspacesController#show`) for signed-in users; other guest requests are redirected to sign in by `authenticate_user!`. Guest pages (Devise views, and the new-project page) use `layouts/devise`, a split view: from `lg` up a decorative panel (inverse `solid` colors, stepped right edge via `clip-path`, a sample JSON response and the bolt, `aria-hidden`) sits beside the form card, and below `lg` only the card shows. The layout sets `--radius-md` and `--radius-xl` to `0rem` on its wrapper, so inputs, buttons, checkboxes and the card render with square corners without touching the shared components.
- `Project` and `Membership` (role `owner`/`member`). `ProjectContext#require_project` redirects any user without an active project to `projects#new`, so every user creates a first project (name + icon) right after sign-up. `Project.create_with_owner` creates the project and its owner membership in one transaction.
- Submit loading: `app/javascript/submit_loading.js` (pinned in `config/importmap.rb`, imported by `application.js`) disables the button that submitted a form and sets `data-loading` on it from `turbo:submit-start` until `turbo:submit-end` (forms with `data-turbo="false"` stay loading until the page unloads); `button[data-loading]` in `application.css` replaces the button's leading icon with a spinner and keeps the label, so every `Button`, `button_to` and `form.button` gets it without extra markup. Buttons always carry an icon plus a label (`Button::Component` requires `icon:`, `Modal::Component` takes `submit_icon:`); only compact icon-only controls and the locale toggle are exempt.
- Destructive confirmations: any `data-turbo-confirm` is routed through `ConfirmDialog` (one `<dialog>` in `layouts/application`, `confirm-dialog` Stimulus controller overriding `Turbo.config.forms.confirm`) instead of the native browser `confirm`.
- Shared UI components (`Button`, `Input`, `Link`, `Logo`, `ThemeSwitcher`, `LocaleSwitcher`) and Stimulus controllers for password visibility, icon picking and dropdowns.
- PostgreSQL schema contains `users`, `projects`, `memberships` and Active Storage tables; the `uuid-ossp` extension is enabled.
- **API Client** (phase 2): `Environment`/`Variable` (secrets encrypted, selected per membership from the status bar), `Collection`, `Folder`, `ApiRequest`, `RequestExecution`; request editor with CodeMirror, history, cURL import/copy, import of Postman/Insomnia/Bruno/OpenAPI collections and environments, drag and drop tree, authorization per request or folder with inheritance (None, Basic, Bearer, API key, JWT, Digest, AWS SigV4, OAuth 2.0). See [`api-client.md`](api-client.md). Sidebar entries *API Client* and *Environments* are live.
- Controllers for the feature live in `Workbench::` and `Projects::` modules; logic is in `app/services` (`ApiClient::` namespace) (`Serviceable` + `Result`).
- **Network Tools** (DNS checker, port check, TCP ping): `Network::` controllers and services, page at `/network` (*Network* entry in the account panel's tools list), no tables and no new gems. See [`network-tools.md`](network-tools.md).
- Gems added: `faraday`, `faraday-multipart`, `jwt`, `aws-sigv4`, `net-http-digest_auth`.
- Tests: RSpec (`spec/`) with FactoryBot, shoulda-matchers, WebMock and ViewComponent test helpers. Run `bundle exec rspec`; SimpleCov enforces 100% line and branch coverage over `app/` (report in `coverage/`, git-ignored). Layout: `spec/models`, `spec/services`, `spec/components`, `spec/requests` (controllers and views), `spec/support`, `spec/factories`. Set `PARTIAL_RUN=1` to run a subset without the minimum check, and `COVERAGE_DIR` to redirect the report. JavaScript (Stimulus) is not covered.

Update this section as features land.

## 10. Open technical questions

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
