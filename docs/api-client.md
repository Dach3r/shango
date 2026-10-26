# Shango — API Client

> How the API Client is built and how to extend it. Product intent lives in [`product.md`](product.md) (§9 *API Client*, roadmap phase 2); the wider architecture in [`architecture.md`](architecture.md). This file describes what exists in the repo today.

## 1. Scope

**Included**

- Collections with nested folders and requests; drag and drop to move requests and folders.
- Open requests as tabs: every request the user opens (from the sidebar or a new draft) stays as a per-user tab above the editor, with a *+* to start a new draft. Opening the workbench with tabs open lands on the last tab; the empty state shows only when none is open. Closing a saved request's tab just closes the tab; closing a draft's tab asks to save or discard it, unless the draft was never edited, which is discarded straight away. Draft requests are per-user requests without a collection; they can be edited and sent, *Save* asks which collection or folder to move them into (when the project has no collection yet it opens the new-collection dialog instead, and the draft is saved into the collection it creates), and closing that dialog keeps the draft. The shortcut *Option/Alt+W* closes the active tab like its *x* button (`request_tabs#closeCurrent`). Browsers reserve *Cmd/Ctrl+W*, so it is not used. Right-clicking a tab opens a menu (same `context_menu` controller, hidden trigger): *New request*, *Duplicate tab*, then *Close tab* (clicks the tab's own close control, so draft confirmation still applies), *Close tabs to the left*, *Close tabs to the right* and *Close all tabs* (`DELETE /workbench/tabs?side=left|right|all&request_id=&current=`, `Tabs::CloseMany`: saved tabs close, untouched drafts are discarded, drafts with edits stay open; the page stays on the current request while its tab survives).
- Request editor: method, URL, query params (kept in sync with the URL), headers, body, authorization, settings.
- Body types: none, JSON, text, XML, GraphQL, form-urlencoded, multipart (text and file fields), binary file.
- Environments with variables (`{{name}}`), a secret flag, and a per-member active environment shown in the top bar.
- Run a request, inspect the response (pretty / raw / HTML preview, headers, request details, the payload sent in its own tab (read-only code editor with highlighting and copy), redirects), per-request history (last 50).
- Import from a cURL command and copy a request as cURL.
- Import whole collections and environments from Postman, Insomnia, Bruno and OpenAPI/Swagger exports (see §9).
- Authorization set per request, or per folder and inherited by its requests: No auth, Basic, Bearer, API key, JWT bearer, Digest, AWS Signature v4, OAuth 2.0 (client credentials, password, authorization code with PKCE; automatic refresh).
- Code editor (CodeMirror 6) with `{{variable}}` autocomplete and highlighting by state: set (green), empty value (amber), undefined (red, wavy underline) and dynamic `$` helpers (accent). The popup shows each variable's value under its name; hovering a `{{variable}}` shows a card with its value (or "Undefined") and its source (Environment or Dynamic). Secret values are masked server-side and never sent.
- Plain inputs in the request editor (params, headers, form data, authorization fields) and the folder form also detect `{{` and offer the same variables in a dropdown (`variable_autocomplete` controller, enabled through `variable_autocomplete_data`); arrow keys move, Enter/Tab accept, Esc closes. The references are highlighted by state like in the code editor (a mirror layer over the field), and a password field shows its text while it holds a `{{reference}}`.

**Not included (yet)**: pre/post-request scripts and assertions, collection runner, cookie jar, WebSocket/gRPC, import of scripts and of Bruno `.bru` folders or Apidog native files, export of collections, OAuth 1.0, Hawk, NTLM, Akamai EdgeGrid, ASAP (auth phase 3, built on demand), sharing/roles (open product question).

## 2. Domain model

All tables use UUID primary keys. `Project` is the tenancy boundary: every record reaches its project and controllers always look records up through `current_project`.

| Model | Notes |
|-------|-------|
| `Environment` | `project_id`, `name` (unique per project), `position`. Has many `Variable`s (nested attributes). |
| `Variable` | `key`, `value` (encrypted), `secret`, `enabled`. A blank submission for a saved secret keeps the stored value. |
| `Membership#current_environment_id` | The environment each member works with in a project (nullable, `nullify` on delete). |
| `Collection` | `name`, `description`, `auth_type` (default `none`), `auth_config` (encrypted JSON); not exposed in the UI, collections carry no authorization. |
| `Folder` | Self-referencing (`parent_id`) inside a collection; `auth_type` defaults to `inherit`. |
| `ApiRequest` | The glossary's *Request*. `collection_id` is nullable: a request with no collection is a draft owned by `user_id` (a CHECK requires an owner and no folder); placing it clears `user_id`. `ApiRequest.visible_to(user)` hides other users' drafts, and controllers look requests up through it. Named `ApiRequest` to avoid clashing with `ActionDispatch::Request`. Rows (`query_params`, `headers`, `body_form`) are JSON arrays of `{key, value, enabled, description}`; `settings` holds timeout, redirects and SSL verification. Files use Active Storage (`body_files`, `binary_body`). |
| `RequestTab` | A request the user has open as a tab (`user_id`, `api_request_id`, unique pair, cascade on delete). Tabs are ordered by creation; opening a request (`Tabs::Open`, called by `requests#show` and `CreateDraft`) is idempotent, `Tabs::Close` only removes the tab. |
| `RequestExecution` | History entry (only when the user saves the response): resolved URL, status, duration, per-phase `timings` (ms, jsonb), headers, body (≤ 5 MB, text only), redirects, unresolved variables, error kind/message. Secrets are masked before saving. Last 50 per request are kept. |

Monitoring and documentation will reference `ApiRequest`; they must not copy its fields (see architecture §4).

`Positionable` orders siblings; `AuthConfigurable` adds `auth_type`/`auth_config` (and validates against the auth registry).

## 3. Code layout

Controllers are grouped in **feature modules**, use plural REST names and stay thin; all logic lives in services (`app/services`, built on `Serviceable`, returning a `Result`). Models stay flat (not namespaced).

```
app/controllers/workbench/           # feature module (routes under /workbench)
  base_controller.rb                 # sidebar tree + modal error rendering
  workspaces_controller.rb           # GET /workbench
  collections_controller.rb          # CRUD (modal forms)
  folders_controller.rb, folders/positions_controller.rb
  requests_controller.rb             # show/update/destroy + modal create
  drafts_controller.rb               # POST = new blank draft
  requests/placements_controller.rb  # modal to save a draft into a collection/folder
  requests/tabs_controller.rb        # DELETE = close a request's tab
  requests/executions_controller.rb  # POST = run (unsaved), GET = history item
  requests/executions/saves_controller.rb  # POST = save a run's response to history
  requests/duplications_controller.rb, requests/positions_controller.rb, requests/curl_exports_controller.rb
  curl_imports_controller.rb
  imports_controller.rb              # GET/POST /workbench/import (collections, folders, requests, environments)
  oauth2/{tokens,authorizations,callbacks}_controller.rb
app/controllers/projects/            # project-level tools
  environments_controller.rb, current_environments_controller.rb, environments/variables_controller.rb
app/controllers/concerns/workbench/request_parameters.rb

app/services/api_client/
  collections/ folders/ requests/    # one class per action: Create, Update, Destroy, Move, Run, ImportCurl, ExportCurl…
  tree/{load,reposition}.rb
  auth/                              # strategy registry (see §5)
  oauth2/                            # token client + services
  curl/{parser,exporter}.rb
  imports/                           # detector, one importer per format, support helpers, Import (persist)
  request_builder.rb executor.rb connection.rb timing.rb ssrf_policy.rb variable_resolver.rb masker.rb
app/services/projects/environments/  # Create, Update, Destroy, Select, UpdateVariable
app/services/result.rb
```

Services are called as `ApiClient::Requests::Run.call(api_request:, environment:, user:, ...)` and return `Result` (`success?`, `record`, `error`, `data`).

UI: ViewComponents under `app/components/<name>/component.rb` (`RequestTree`, `KeyValueTable`, `CodeEditor`, `AuthFields`, `TabBar`, `Modal`, `EnvironmentSwitcher`, `MethodBadge`, `StatusBadge`, `Oauth2Forms`) and Stimulus controllers under `app/javascript/controllers` (`code_editor`, `tabs`, `key_value_table`, `request_form`, `request_url`, `body_type`, `auth_form`, `conditional_fields`, `tree`, `dialog`, `response_body`, `inline_rename`, `resizable`). The response panel height is resizable by dragging (or arrow keys on) the handle on its top border; it can grow until only the URL bar remains visible above it, the height is remembered in `localStorage`, and a double click on the handle restores the default (`resizable`). Collections and folders expand and collapse with a double click by default; each member can switch to single click in *Settings* (`memberships.folder_toggle`, passed to the `tree` controller as `data-tree-toggle-value`; with double click, the name still renames and the rest of the row toggles); the chevron always toggles on a single click and points right when closed, down when open. Closing a collection or folder also closes every folder nested inside it unless the member turns off *Collapse nested folders* in *Settings* (`memberships.collapse_nested_folders`, default on, `data-tree-collapse-nested-value`); the open/closed state is remembered in `localStorage`; restoring it on load does not cascade). Tree rows show no focus outline. With `memberships.request_open = double_click` (`data-tree-open-value`) a request row only opens on double click, and its name no longer renames in place. Right-clicking a collection, folder or request row opens its actions menu (the same one as the hover "…" button, `context_menu` controller) at the pointer; each item has an icon, and *Rename* starts the in-place rename (requests also get *Duplicate* and *Delete* there). Double-clicking a collection, folder or request name in the sidebar renames it in place (`inline_rename` PATCHes only the name to the regular update endpoint; request rows delay navigation ~220 ms so a double click is not read as a click). Changing the method in the editor selector restyles that request's badge in the sidebar and tab bar right away, before saving (`request_form#methodChanged` over `[data-method-badge]`, presets from `MethodBadge::Component.presets`). While a request is running the *Send* button turns into *Cancel*; clicking it aborts the fetch (`request_form#toggle`) and leaves the response panel untouched. Key/value tables (params, headers, form data, variables) render as a bordered card with a column header (params and headers), borderless cells and a hover-only remove button; rows are only added with the *Add* button below the table (focusing the new row's key), never automatically. Modal forms render into a `modal` Turbo Frame. Strings live in `config/locales/workbench.{en,es}.yml`.

## 4. Execution pipeline

Hovering a `{{variable}}` in any editor opens a card with its value as an input: edits save to the selected environment through `PATCH /environments/:environment_id/variables/:id` (debounced, on change and when the card closes) and every editor on the page refreshes its highlighting. Secrets arrive masked, so their input starts empty and a blank save keeps the stored value. Hovering an undefined variable shows an empty input too: typing a value creates the variable in the selected environment (`POST /environments/:environment_id/variables`, reusing and re-enabling a disabled variable with the same key) and every editor picks it up. Without a selected environment it stays read-only, and so do dynamic variables.

1. `RequestBuilder` resolves `{{variables}}` from the selected environment (plus `{{$timestamp}}`, `{{$isoTimestamp}}`, `{{$guid}}`, `{{$randomInt}}`), builds URL, headers and body, resolves the effective auth and applies it. Undefined variables in the URL abort the run with a clear message; elsewhere they are sent as typed and reported in the response.
2. `Executor` sends the request with Faraday (`Net::HTTP`). Redirects are followed by the executor itself, so each hop goes through the SSRF policy; credential headers are dropped when a redirect leaves the origin. A Digest `401` challenge is answered once. `Timing` measures the call: DNS (the SSRF resolution in `Connection.build`), TCP and TLS (hooks on the `Net::HTTP` connection), waiting for the first byte (TTFB) and download, summed across redirect hops; `process` is the rest of the total. They are stored in `RequestExecution#timings` and the duration chip in the response panel opens a waterfall popover with them (not shown for failed requests or executions without timings).
3. `Requests::Run` builds a `RequestExecution` with secrets masked but does not write it to the database: it is stashed in `Rails.cache` (30 minutes) under its pre-generated id. The response panel shows a *Save response* button (not for failed requests) that POSTs to `executions/:execution_id/saves`; `Executions::Save` persists the cached execution (same request and user only), drops it from the cache and prunes history to the last 50. An expired response answers `410 Gone`.

`Requests::Run` first saves any pending edits of the editor form, so *Send* also saves. The response is streamed back as a Turbo Stream into the response panel.

Limits: timeout 30 s by default (max 120 s, per request), 5 MB read limit (the response is cut and flagged; what is read is stored and displayed whole so JSON stays formattable), binary or non-text bodies are not stored.

## 5. Authentication strategies

`ApiClient::Auth::Registry` lists strategies (`STRATEGIES`). A strategy subclasses `ApiClient::Auth::Base`, declares `field`s (they generate the form, including secrets and `show_when` conditions) and implements `apply(request)`; optionally `respond_to_challenge` (Digest) or `managed_keys` (OAuth tokens).

To add a method (phase 3 candidates: OAuth 1.0, Hawk, NTLM, Akamai EdgeGrid, ASAP):

1. Create `app/services/api_client/auth/<name>.rb` with the fields and `apply`.
2. Add its class name to `Registry::STRATEGIES`.
3. Add labels under `workbench.auth.types.<key>` and `workbench.auth.fields.*` in both locale files.

Delivery phases: **1** None, Basic, Bearer, API key; **2** OAuth 2.0, JWT bearer, Digest, AWS SigV4 (all implemented); **3** others on demand.

Inheritance: a request or folder with `inherit` uses the nearest ancestor that does not; collections have no authorization UI, so a request or folder with nothing above it sends *No auth*, and so does a draft that inherits. `Auth::EffectiveAuth` resolves it. OAuth tokens are stored on the record that owns the OAuth settings and refreshed automatically before they expire.

## 6. Security

- **Encryption at rest** (Active Record Encryption): variable values, `auth_config` (credentials, OAuth tokens). Keys come from `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (generate with `bin/rails db:encryption:init`); when unset they are derived from `secret_key_base`, so rotating `secret_key_base` makes stored secrets unreadable. Set explicit keys on any real install. See `config/initializers/active_record_encryption.rb`.
- **Masking**: secret variable values and credentials are replaced by `••••••` in the stored request (URL, sensitive headers, body) and in the stored response (headers and body, since APIs often echo credentials). Saved secrets are never rendered back into forms (a placeholder asks to leave the field blank to keep it).
- **Logs**: `auth_config`, `variables_attributes`, `value` and `body` are added to `filter_parameters`.
- **SSRF**: off by default because self-hosted users legitimately call localhost and private networks. Set `SHANGO_BLOCK_PRIVATE_NETWORKS=true` on shared or cloud deployments to block loopback, private, link-local and metadata ranges (checked on every redirect hop; the connection is pinned to the checked address). OAuth token calls go through the same policy.
- **Copy as cURL** returns the request resolved against the selected environment, credentials included, because the user asked for it explicitly.
- Strong parameters are declared in controllers; services only receive permitted data.

## 7. Code editor (CodeMirror 6)

CodeMirror is vendored as **one** esbuild bundle at `vendor/javascript/codemirror.js` and pinned in `config/importmap.rb` (`pin "codemirror", to: "codemirror.js"`). A single bundle avoids loading several copies of `@codemirror/state`, which breaks editors with *Unrecognized extension value*. It is imported lazily by `code_editor_controller.js` but pinned with `preload: true` (`modulepreload`), so the download overlaps with the page load. Until the editor mounts, read-only editors (response body) show a pulsing skeleton instead of the raw fallback textarea; editable ones keep the textarea so the form works without JS.

To rebuild (Node is needed only for this):

```sh
mkdir cm && cd cm && npm init -y
npm i codemirror @codemirror/state @codemirror/view @codemirror/commands @codemirror/language \
  @codemirror/lang-json @codemirror/lang-xml @codemirror/lang-javascript @codemirror/lang-html \
  @codemirror/autocomplete @codemirror/search @lezer/highlight esbuild
# entry.js re-exports every package: export * from "@codemirror/state" ... (one line per package)
npx esbuild entry.js --bundle --format=esm --minify --target=es2022 --outfile=codemirror.js
cp codemirror.js ../vendor/javascript/codemirror.js
```

Current build: codemirror 6.0.2, @codemirror/state 6.7.6, @codemirror/view 6.43.15. Verified with Turbo Drive back/forward (no duplicated editors), Turbo Stream replacement and light/dark themes.

## 8. Development notes

- Do not run `bin/rails tailwindcss:build` or `assets:precompile` in development: they create `public/assets`, which makes Propshaft serve a stale manifest. If CSS or new assets seem frozen, delete `public/assets`.
- The editor form is multipart. New files are saved with the request; *Send* refreshes the page after uploads so file rows pick up their stored ids.

## 9. Importing collections

*Import* (upload icon in the sidebar header, `GET/POST /workbench/import`) accepts a file or pasted text, JSON or YAML, up to 5 MB, and detects the format by itself (`ApiClient::Imports::Detector`):

| Source | Supported export |
|--------|------------------|
| Postman | Collection v2.x and environment files |
| Insomnia | v4 JSON export, v5 YAML/JSON |
| Bruno | JSON export of a collection |
| OpenAPI | OpenAPI 3.x and Swagger 2.0 (JSON or YAML) |
| Apidog | Export the project as Postman or OpenAPI and import that file |

Pipeline: `Imports::Import` parses the content (`JSON.parse`, then `YAML.safe_load` without classes or aliases), runs the `Detector`, calls the format importer (`Postman`, `Insomnia`, `Bruno`, `Openapi`: pure functions that return a normalized tree of collections, folders, requests and environments plus `warnings`) and persists it in **one transaction** through the regular `Collections::Create`, `Folders::Create`, `Requests::Create` and `Projects::Environments::Create` services, always inside the current project. Any failure rolls everything back. Requests use the same attribute hash as `Curl::Parser`.

Mapping rules:

- Existing collection or environment names get a ` (2)`, ` (3)` suffix; nothing is overwritten.
- Auth maps to the strategy registry (basic, bearer, API key, digest, AWS SigV4, OAuth 2.0 with client credentials/password/authorization code, Postman JWT is not mapped); anything else becomes *inherit* with a warning. Collection-level auth is pushed down to top-level folders and requests, since collections carry no authorization.
- Variables: Insomnia `{{ _.name }}` becomes `{{name}}`, Postman `{{$randomUUID}}` becomes `{{$guid}}`; unsupported dynamic helpers are kept as typed and reported. Postman collection variables become an environment named `<collection> variables`; Insomnia sub-environments are merged over the base environment and nested data is flattened to `a.b` keys; Bruno and Postman secret flags are kept. Variables whose name is not a valid key are skipped with a warning.
- OpenAPI: tags become folders, the first server (or `host` + `basePath`) becomes the `baseUrl` environment variable and URLs use `{{baseUrl}}`; path parameters become `{{param}}`; optional query and header parameters are imported disabled; request bodies are generated from examples or schemas (local `$ref`s only, depth-limited).
- Not imported (reported as warnings): scripts, tests, file contents of file bodies, unsupported auth types, external `$ref`s.
- Limits: 5 MB, 250 000 JSON nodes. Secrets travel through the encrypted models and `content`/`file` params are filtered from logs. Nothing is fetched from the network.

Fixtures for each format live in `spec/fixtures/files/imports/`.

## 10. Open questions

- Team model: who can see or edit shared collections and environments (product open question).
- Cookie jar and `Set-Cookie` handling (response cookies are shown merged into one header).
- Export of collections, and import of Bruno `.bru` folders / Apidog native files.
- Automated tests: the repository has no test framework yet; the feature was verified manually and with throwaway scripts.
