# Shango — API Client

> How the API Client is built and how to extend it. Product intent lives in [`product.md`](product.md) (§9 *API Client*, roadmap phase 2); the wider architecture in [`architecture.md`](architecture.md). This file describes what exists in the repo today.

## 1. Scope

**Included**

- Collections with nested folders and requests; drag and drop to move requests and folders.
- Open requests as tabs: every request the user opens (from the sidebar or a new draft) stays as a per-user tab above the editor, with a *+* to start a new draft. Opening the workbench with tabs open lands on the last tab; the empty state shows only when none is open. Closing a saved request's tab just closes the tab; closing a draft's tab asks to save or discard it, unless the draft was never edited, which is discarded straight away. Draft requests are per-user requests without a collection; they can be edited and sent, *Save* asks which collection or folder to move them into (when the project has no collection yet it opens the new-collection dialog instead, and the draft is saved into the collection it creates), and closing that dialog keeps the draft. The shortcut *Option/Alt+W* closes the active tab like its *x* button (`request_tabs#closeCurrent`). Browsers reserve *Cmd/Ctrl+W*, so it is not used. Right-clicking a tab opens a menu (same `context_menu` controller, hidden trigger): *New request*, *Duplicate tab*, then *Close tab* (clicks the tab's own close control, so draft confirmation still applies), *Close tabs to the left*, *Close tabs to the right* and *Close all tabs* (`DELETE /workbench/tabs?side=left|right|all&request_id=&current=`, `Tabs::CloseMany`: saved tabs close, untouched drafts are discarded, drafts with edits stay open; the page stays on the current request while its tab survives).
- Request editor: method, URL, query params (kept in sync with the URL), headers, body, authorization, settings.
- Body types: none, JSON, text, XML, GraphQL, form-urlencoded, multipart (text and file fields), binary file.
- Environments with variables (`{{name}}`), a secret flag, and a per-member active environment shown in the status bar. The environments side panel lists them as cards with an "Activate" button (the active one shows "In use") and an actions menu for edit and delete.
- Run a request, inspect the response (pretty / raw / HTML preview, headers, request details (method and URL with host, path and query styled apart, redirect hops as a chain, sent headers in the same table as the response headers), the payload sent in its own tab (read-only code editor with highlighting and copy), redirects), per-request history (last 50), plus a global history view in the left sidebar (the history icon swaps the collections list for it, with a back arrow) with the user's saved responses grouped by collection (drafts last, latest 200).
- Import from a cURL command and copy a request as cURL.
- Import whole collections and environments from Postman, Insomnia, Bruno and OpenAPI/Swagger exports (see §9).
- Authorization set per request, or per folder and inherited by its requests: No auth, Basic, Bearer, API key, JWT bearer, Digest, AWS Signature v4, OAuth 2.0 (client credentials, password, authorization code with PKCE; automatic refresh).
- Code editor (CodeMirror 6) with `{{variable}}` autocomplete and highlighting by state: set (green), empty value (amber), undefined (red, wavy underline) and dynamic `$` helpers (accent). The popup shows each variable's value under its name; hovering a `{{variable}}` shows a card with its value (or "Undefined") and its source (Environment or Dynamic). Secret values are masked server-side and never sent.
- Plain inputs in the request editor (params, headers, form data, authorization fields) and the folder form also detect `{{` and offer the same variables in a dropdown (`variable_autocomplete` controller, enabled through `variable_autocomplete_data`); arrow keys move, Enter/Tab accept, Esc closes. The references are highlighted by state like in the code editor (a mirror layer over the field), and a password field shows its text while it holds a `{{reference}}`.

**Not included (yet)**: pre/post-request scripts and assertions, collection runner, WebSocket/gRPC, import of scripts and of Bruno `.bru` folders or Apidog native files, export of collections, OAuth 1.0, Hawk, NTLM, Akamai EdgeGrid, ASAP (auth phase 3, built on demand), sharing/roles (open product question).

## 2. Domain model

All tables use UUID primary keys. `Project` is the tenancy boundary: every record reaches its project and controllers always look records up through `current_project`.

| Model | Notes |
|-------|-------|
| `Environment` | `project_id`, `name` (unique per project), `position`. Has many `Variable`s (nested attributes). |
| `Variable` | `key`, `value` (encrypted), `secret`, `enabled`. A blank submission for a saved secret keeps the stored value. |
| `Cookie` | The cookie jar: one row per `project_id` + `environment_id` (nullable, cascade) + `domain` + `path` + `name` (unique, nulls not distinct). `value` is encrypted; also `host_only`, `secure`, `http_only`, `expires_at`. Capped at 200 per jar (least recently updated are evicted). |
| `Membership#current_environment_id` | The environment each member works with in a project (nullable, `nullify` on delete). |
| `Collection` | `name`, `description`, `auth_type` (default `none`), `auth_config` (encrypted JSON); not exposed in the UI, collections carry no authorization. |
| `Folder` | Self-referencing (`parent_id`) inside a collection; `auth_type` defaults to `inherit`. |
| `ApiRequest` | The glossary's *Request*. `collection_id` is nullable: a request with no collection is a draft owned by `user_id` (a CHECK requires an owner and no folder); placing it clears `user_id`. `ApiRequest.visible_to(user)` hides other users' drafts, and controllers look requests up through it. Named `ApiRequest` to avoid clashing with `ActionDispatch::Request`. Rows (`query_params`, `headers`, `body_form`) are JSON arrays of `{key, value, enabled, description}`; `settings` holds timeout, redirects and SSL verification. Files use Active Storage (`body_files`, `binary_body`). |
| `RequestTab` | A request the user has open as a tab (`user_id`, `api_request_id`, unique pair, cascade on delete). Tabs are ordered by creation; opening a request (`Tabs::Open`, called by `requests#show` and `CreateDraft`) is idempotent, `Tabs::Close` only removes the tab. |
| `RequestExecution` | History entry (only when the user saves the response): resolved URL, status, duration, per-phase `timings` (ms, jsonb), headers, body (≤ 5 MB, text only), redirects, unresolved variables, `set_cookies` (each `Set-Cookie` of the final response as its own line, secrets masked), error kind/message. Secrets are masked before saving. Last 50 per request are kept. |

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

UI: ViewComponents under `app/components/<name>/component.rb` (`RequestTree`, `KeyValueTable`, `CodeEditor`, `AuthFields`, `TabBar`, `Modal`, `ResponseReferenceModal`, `EnvironmentSwitcher`, `MethodBadge`, `StatusBadge`, `Oauth2Forms`) and Stimulus controllers under `app/javascript/controllers` (`code_editor`, `tabs`, `key_value_table`, `request_form`, `request_url`, `body_type`, `auth_form`, `conditional_fields`, `tree`, `dialog`, `response_body`, `inline_rename`, `resizable`). The response panel height is resizable by dragging (or arrow keys on) the handle on its top border; it can grow until only the URL bar remains visible above it, the height is remembered in `localStorage`, and a double click on the handle restores the default (`resizable`). Collections and folders expand and collapse with a double click by default; each member can switch to single click in *Settings* (`memberships.folder_toggle`, passed to the `tree` controller as `data-tree-toggle-value`; with double click, the name still renames and the rest of the row toggles); the chevron always toggles on a single click and points right when closed, down when open. Closing a collection or folder also closes every folder nested inside it unless the member turns off *Collapse nested folders* in *Settings* (`memberships.collapse_nested_folders`, default on, `data-tree-collapse-nested-value`); the open/closed state is remembered in the `api_client_tree_closed` cookie (written by `tree`, read by the workspace partial and passed as `closed_ids` so a reload renders branches already collapsed, with no open-then-close flash)). Tree rows show no focus outline. With `memberships.request_open = double_click` (`data-tree-open-value`) a request row only opens on double click, and its name no longer renames in place. Right-clicking a collection, folder or request row opens its actions menu (the same one as the hover "…" button, `context_menu` controller) at the pointer; each item has an icon, and *Rename* starts the in-place rename (requests also get *Duplicate* and *Delete* there). Double-clicking a collection, folder or request name in the sidebar renames it in place (`inline_rename` PATCHes only the name to the regular update endpoint; request rows delay navigation ~220 ms so a double click is not read as a click). Changing the method in the editor selector restyles that request's badge in the sidebar and tab bar right away, before saving (`request_form#methodChanged` over `[data-method-badge]`, presets from `MethodBadge::Component.presets`). While a request is running the *Send* button turns into *Cancel*; clicking it aborts the fetch (`request_form#toggle`) and leaves the response panel untouched. Key/value tables (params, headers, form data, variables) render as a bordered card with a column header (params and headers), borderless cells and a hover-only remove button; rows are only added with the *Add* button below the table (focusing the new row's key), never automatically. Showing a request opens its tab (`RequestsController#show`), so Turbo prefetch-on-hover is disabled (`turbo-prefetch` meta in the layout) and requests carrying a `Sec-Purpose`/`X-Sec-Purpose: prefetch` header never open tabs; otherwise hovering a link could open a tab nobody asked for. Modal forms render into a `modal` Turbo Frame. Strings live in `config/locales/workbench.{en,es}.yml`.

## 4. Execution pipeline

Hovering a `{{variable}}` in any editor opens a card with its value as an input: edits save to the selected environment through `PATCH /environments/:environment_id/variables/:id` (debounced, on change and when the card closes) and every editor on the page refreshes its highlighting. Secrets arrive masked, so their input starts empty and a blank save keeps the stored value. Hovering an undefined variable shows an empty input too: typing a value creates the variable in the selected environment (`POST /environments/:environment_id/variables`, reusing and re-enabling a disabled variable with the same key) and every editor picks it up. Without a selected environment it stays read-only, and so do dynamic variables.

**Response references.** `{{response.<attr>.<request_id>[.<filter>]}}` takes a value from the latest response of another request **in the same collection** (drafts, other collections and other projects never resolve). `attr` is `body` (filter is a JSONPath such as `$.data[0].id`), `raw` (whole body), `header` (filter is the header name, case-insensitive) or `url` (final request URL); `request_id` is the source request's UUID. The source is the user's latest response for that request: the last run still cached (even if not saved, `RequestExecution.latest_for` through the `request_execution/latest/<request>/<user>` pointer written by `#stash`), else the newest saved one. Values come from the stored, already masked response, so secrets stay masked. A scalar becomes its string, objects and arrays become JSON, several matches become a JSON array. No response, an errored response or no match leaves the reference unresolved (it aborts the run when used in the URL, like an undefined variable). `{{` inside a fetched value is broken up (`{ {`) so a response cannot inject variable references. Filters cannot contain spaces. Nothing is re-sent automatically (Insomnia's trigger behavior is always *never*). In the editors, typing `{{` also offers `response.body`, `response.raw`, `response.header` and `response.url` (only when the collection has other requests). Picking one writes a ready reference (first request of the collection; `$` or `Content-Type` as filter) and opens an *Edit response reference* modal like Insomnia's *Edit Tag*: attribute, request (`[folder] METHOD name`), filter (JSONPath for body, header name for header; hidden for raw and url), trigger behavior (only *Never*, shown disabled) and a live preview; *Done* rewrites the reference in place. Clicking an existing `{{response.…}}` reopens the modal (`lib/response_reference.js#openResponseModal`, shared by `code_editor` and `variable_autocomplete`). The modal is server-rendered by `ResponseReferenceModal::Component` (built from `Modal` and `Select`) as a `<template id="response-reference-template">` inside the request editor; the JS clones it, so it only renders when the collection has other requests. In the code editors a valid reference is shown as a chip (`request name · attribute · filter`, `code_editor#referenceChips`, a replace widget that is atomic for the cursor; the stored text is unchanged) that opens the modal on click; in plain inputs and for references to unknown requests it stays highlighted text (dynamic style, or undefined), and hovering one in a code editor shows the request, the attribute and the live value (`GET /workbench/requests/:request_id/response_reference?name=`, `Requests::ResponseReferencesController`, values cut at 500 characters). Data reaches the editors through `editor_responses`/`editor_responses_url` (empty for drafts). Implemented by `ApiClient::ResponseReference`, plugged into `VariableResolver` through its `extra:` lookup by `RequestBuilder` when it gets a `user:`.

1. `RequestBuilder` resolves `{{variables}}` from the selected environment (plus `{{$timestamp}}`, `{{$isoTimestamp}}`, `{{$guid}}`, `{{$randomInt}}`), builds URL, headers and body, resolves the effective auth and applies it. Undefined variables in the URL abort the run with a clear message; elsewhere they are sent as typed and reported in the response.
2. `Executor` sends the request with Faraday (`Net::HTTP`). Redirects are followed by the executor itself, so each hop goes through the SSRF policy; credential headers are dropped when a redirect leaves the origin. A Digest `401` challenge is answered once. With a `CookieJar` (built by `Dispatch` for the project and the selected environment) every hop sends the matching stored cookies and keeps the ones its `Set-Cookie` sets, so a sign-in request makes the next request authenticated like in Postman or Insomnia. A `Cookie` header typed in the request wins over stored cookies with the same name. A request can opt out in its *Settings* tab (`settings.use_cookie_jar`, default on): `Dispatch` then gives the `Executor` no jar, so it neither sends stored cookies nor keeps the ones the response sets. Matching follows RFC 6265 (host-only vs `Domain`, path prefix, `Secure` only over https, `Max-Age` over `Expires`, expired cookies are deleted); cookies are shared by every request of the same project and environment, and never across them. The environment picker has a *Cookies* entry that opens a side panel (`GET /cookies`, `Projects::CookiesController`) listing the jar of the selected environment (name, domain, path, expiry, `Secure`/`HttpOnly`; values are never rendered) with per-cookie delete (`DELETE /cookies/:id`) and *Clear all cookies* (`DELETE /cookie_jar`, `Projects::CookieJarsController`). `Timing` measures the call: DNS (the SSRF resolution in `Connection.build`), TCP and TLS (hooks on the `Net::HTTP` connection), waiting for the first byte (TTFB) and download, summed across redirect hops; `process` is the rest of the total. They are stored in `RequestExecution#timings` and the duration chip in the response panel opens a waterfall popover with them, and a *Timing* tab lists the same phases (plus the total) in the headers table layout (neither is shown for failed requests or executions without timings). A *Cookies* tab lists each cookie the final response set on its own row (name, value, domain, path, expiry, `Secure`/`HttpOnly`); `ApiClient::SetCookie` splits the merged `Set-Cookie` header the HTTP client returns and parses each line, and the cookie jar uses the same parser.
3. `Requests::Run` saves the pending edits and hands the send to `Requests::Dispatch`, which builds a `RequestExecution` with secrets masked but does not write it to the database. **Inline mode** (`SHANGO_EXECUTION_MODE=inline`, default in development and test) sends in the web request. **Async mode** (default in production; needs a Solid Queue worker: `bin/jobs` or `SOLID_QUEUE_IN_PUMA=true`) enqueues `RunRequestJob` (`executions` queue, at most 2 concurrent runs per user, extra ones wait) and answers `202` with the *Sending request…* panel and an `X-Execution-Id` header; the browser (`request_form` controller) polls `GET executions/:execution_id/result` every 500 ms (`202` while running, the response panel when done, `204` if cancelled, `410` if the cached response expired, `422` if the job failed; 3-minute client timeout). *Cancel* POSTs `executions/:execution_id/cancellation`; the worker checks the flag between chunks and redirect hops and finishes with a `cancelled` error. Run state (`Executions::RunState`) lives in the cache for 5 minutes and is only visible to its user and request. Polling was chosen over a Turbo Stream broadcast so a result can never be lost to a late socket subscription and the feature works without Action Cable. In both modes the execution is stashed in `Rails.cache` (30 minutes) under its pre-generated id: it is stashed in `Rails.cache` (30 minutes) under its pre-generated id. The response panel shows a *Save response* button (not for failed requests) that POSTs to `executions/:execution_id/saves`; `Executions::Save` persists the cached execution (same request and user only), drops it from the cache and prunes history to the last 50. An expired response answers `410 Gone`.

`Requests::Run` first saves any pending edits of the editor form, so *Send* also saves. The response is streamed back as a Turbo Stream into the response panel.

Uploads (multipart file rows and the binary body) are limited per submission: 10 MB per file (`SHANGO_MAX_UPLOAD_MB`), 25 MB in total (`SHANGO_MAX_UPLOADS_TOTAL_MB`) and 10 files (`SHANGO_MAX_UPLOADS`); beyond that the save fails with a form error and nothing is stored (`Requests::Update`). Also cap request bodies at the proxy (e.g. Thruster `MAX_REQUEST_BODY`) so oversized uploads never reach Rails.

History: saved responses keep at most 256 KB of body (and of request body; `RequestExecution::STORED_BODY_BYTES`, flagged `body_truncated`) and are deleted after 90 days (`SHANGO_HISTORY_RETENTION_DAYS`, `0` keeps them; `PruneRequestExecutionsJob`, daily). The unsaved execution cached for 30 minutes is cut the same way. Masking also covers base64, url-safe base64 and percent-encoded forms of each secret.

Limits: timeout 30 s by default (max 120 s, per request; it is the per-attempt timeout, and the whole execution including redirects and digest retries is also capped at 120 s, `Executor::MAX_DURATION`, so a slow server cannot hold a web thread), at most 10 redirects (`ApiRequest::MAX_REDIRECTS`), 5 MB read limit (the response is cut and flagged; what is read is stored and displayed whole so JSON stays formattable), binary or non-text bodies are not stored.

## 5. Authentication strategies

`ApiClient::Auth::Registry` lists strategies (`STRATEGIES`). A strategy subclasses `ApiClient::Auth::Base`, declares `field`s (they generate the form, including secrets and `show_when` conditions) and implements `apply(request)`; optionally `respond_to_challenge` (Digest) or `managed_keys` (OAuth tokens).

To add a method (phase 3 candidates: OAuth 1.0, Hawk, NTLM, Akamai EdgeGrid, ASAP):

1. Create `app/services/api_client/auth/<name>.rb` with the fields and `apply`.
2. Add its class name to `Registry::STRATEGIES`.
3. Add labels under `workbench.auth.types.<key>` and `workbench.auth.fields.*` in both locale files.

Delivery phases: **1** None, Basic, Bearer, API key; **2** OAuth 2.0, JWT bearer, Digest, AWS SigV4 (all implemented); **3** others on demand.

Inheritance: a request or folder with `inherit` uses the nearest ancestor that does not; collections have no authorization UI, so a request or folder with nothing above it sends *No auth*, and so does a draft that inherits. `Auth::EffectiveAuth` resolves it. OAuth tokens are stored on the record that owns the OAuth settings and refreshed automatically before they expire.

## 6. Security

- **Encryption at rest** (Active Record Encryption): variable values, `auth_config` (credentials, OAuth tokens). Keys come from `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (generate with `bin/rails db:encryption:init`); **production refuses to boot without all three** (`Shango::EncryptionKeys`); development and test derive them from `secret_key_base`. Upgrading an install that ran on derived keys: run `bin/rails shango:encryption:derived_keys` and copy its output into the environment (no data is re-encrypted), or set `SHANGO_ALLOW_DERIVED_ENCRYPTION_KEYS=true` as a stopgap (rotating `secret_key_base` then makes stored secrets unreadable). **Rotation:** generate a new primary key (`bin/rails db:encryption:init`), append it after the current one in `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` (comma separated, newest last: Rails encrypts with the last key and decrypts with all), deploy, run `bin/rails shango:encryption:rotate` (re-encrypts variable values and every `auth_config`), then drop the old key from the list. Deterministic key and salt are not used for any current attribute; do not change them.
- **Masking**: secret variable values and credentials are replaced by `••••••` in the stored request (URL, sensitive headers, body) and in the stored response (headers and body, since APIs often echo credentials). Saved secrets are never rendered back into forms (a placeholder asks to leave the field blank to keep it).
- **Logs**: `auth_config`, `variables_attributes`, `value` and `body` are added to `filter_parameters`.
- **SSRF**: private-network blocking is **on by default in production** and off in development and test. The operator decides: set `SHANGO_BLOCK_PRIVATE_NETWORKS=false` on a self-hosted install that must reach localhost or internal services (understand that every project member can then send requests from the server into your network), or `=true` to force it in any environment. Blocked ranges: loopback, private, link-local and cloud metadata (`169.254.169.254`), carrier-grade NAT, multicast/reserved, plus the IPv6 equivalents including NAT64 and 6to4; IPv4-mapped IPv6 is unwrapped first. It is checked on every redirect hop and the connection is pinned to the checked address. OAuth token calls go through the same policy.
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
- Cookie jar: editing cookies by hand and a public suffix list for `Domain` validation (today a heuristic rejects single-label domains).
- Export of collections, and import of Bruno `.bru` folders / Apidog native files.
- Automated tests: the repository has no test framework yet; the feature was verified manually and with throwaway scripts.
