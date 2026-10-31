# Shango — Scripting, assertions and collection runner

> Design of the API Client's test automation: declarative assertions and extractors, JavaScript scripts with a Postman-compatible `pm.*` API, and the collection runner. Product intent lives in [`product.md`](product.md) (§9 *API Client*); the API Client itself in [`api-client.md`](api-client.md). Status of each phase is in §12; nothing below should be assumed to exist until its phase is marked done.

## 1. Why

Without scripts, assertions and a runner, the API Client is a manual tool: flows that chain calls (log in, keep the `token`, create a booking, keep its `bookingId`) need hand-edited variables, and nothing tells a developer that a response is *wrong* as opposed to *received*. This feature closes that gap in three layers, each useful on its own:

| Layer | What | Runs user code |
|---|---|---|
| **A. Assertions and extractors** | Rows in the UI: `status equals 200`, `$.token exists`, `header X contains …`. Extractors copy a value from the response into an environment variable. | No |
| **B. Scripts** | JavaScript before (`pre-request`) and after (`post-response`) a request, with a `pm.*` API compatible with Postman. | Yes, in a sandbox |
| **C. Collection runner** | Runs a collection or folder in order and reports passes and failures. | Only A and B |

Layer A covers most real needs with zero code execution risk, and its evaluator is shared with Monitoring (body checks, [`monitoring.md`](monitoring.md) §2 *Out of v1*), so it lives in a neutral place (`ApiClient::Assertions`).

## 2. Engine decision

Spike done on macOS (Ruby 4.0.4) with both candidates:

| | `quickjs` 0.22 (MIT) | `mini_racer` 0.22 (MIT, V8) |
|---|---|---|
| Install | native build, seconds | native build + `libv8-node` download |
| Cold context | ~0.1 ms | ~1.2 ms |
| 200 contexts | 23 ms | 246 ms |
| Infinite loop | `Quickjs::InterruptedError` at the timeout | `ScriptTerminatedError` |
| Memory bomb | `out of memory` at the limit | `V8OutOfMemoryError` |
| `require`, `process`, `fetch`, `XMLHttpRequest` | `undefined` | `undefined` |
| Host functions | `define_function`, synchronous | `attach`, synchronous |

**Chosen: `quickjs`.** Smaller, an order of magnitude cheaper per context (a run creates one per script), simpler to deploy, and enough ES2023 for test scripts. Both licenses are AGPL-compatible. If a real workload needs V8 speed, `Scripting::Sandbox` is the only class that touches the engine.

## 3. Sandbox rules

`ApiClient::Scripting::Sandbox` runs one script in a **fresh QuickJS context with no way out**. `pm.js` (next to it) defines the whole `pm` API; what the script may see goes in as **one JSON document** and what it changed comes back as **another**, so the only thing that crosses the boundary is data.

- **No ambient access.** No host functions, no `require`, filesystem, network, `fetch`, timers or modules. A spec asserts `require`, `process`, `fetch`, `XMLHttpRequest`, `std`, `os`, `setTimeout`, `WebSocket` and `importScripts` are all `undefined`.
- **Limits per script** (ENV, with ceilings): `SHANGO_SCRIPT_TIMEOUT_MS` (default 2 000, 100 to 10 000), `SHANGO_SCRIPT_MEMORY_MB` (default 32, 4 to 128), source at most 64 KB, response body given to the script cut at 1 MB, console lines at most 200 of 2 000 characters (64 KB in all), at most 100 tests (names cut to 200 characters, messages to 500), at most 50 variable writes of 64 KB each, result at most 2 MB. Engine errors (timeout, out of memory, stack overflow, syntax) are ordinary script errors.
- **Fresh context per script.** Nothing persists between scripts or runs except variables explicitly written; one script cannot see another's globals.
- **Failures never crash the host.** An exception anywhere (engine, bad JSON, invalid UTF-8, overridden builtins) is a script error. A script error in a *pre-request* script aborts that request before it is sent (`error_kind: script_error`, the request never goes out); in a *post-response* script it becomes a failed outcome and the response is still returned.
- **Secrets.** A script can read secret variables, exactly as a request can already send them to a URL the member controls, so this is no new class of exposure. Everything a script produces (console, test names, failure messages, the error of a failed pre-request script) goes through `Masker` before it is stored or rendered, and values a script writes to a variable that is secret in the environment are masked too (the variable keeps its secret flag).
- **Authorization.** Editing scripts needs `update?` on the request, folder or collection (creator or owner). Running only needs `execute?`.
- **Dependency.** `quickjs` (MIT; QuickJS is MIT too), a native extension: the production image needs a C toolchain at build time (the standard Rails `Dockerfile` has it).

## 4. The `pm` API (v1)

Subset of Postman's API, so imported scripts mostly work:

- `pm.environment.get(key)` / `set(key, value)` / `unset(key)` / `has(key)` / `toObject()`: the selected environment (§6 for persistence). Values are strings (other values are stringified, objects as JSON). `unset` removes a value a script set earlier, but cannot delete a variable of the environment.
- `pm.variables` (and `pm.collectionVariables`): same methods plus `replaceIn("{{x}}")`, run-scoped, never persisted.
- `pm.request`: `url`, `method`, `body` (strings) and `headers` (`get`, `has`, `toObject`, and in *pre-request* scripts `add`, `upsert`, `remove`). A pre-request script sees the request **as saved, `{{variables}}` unresolved**, and what it changes is what gets sent (the saved request is never touched); in post-response scripts it is a read-only copy. Only `GET POST PUT PATCH DELETE HEAD OPTIONS` are accepted as a method.
- `pm.response` (post-response only): `code`, `status`, `responseTime`, `headers.get/has`, `text()`, `json()`, and `pm.response.to.have.status(n)` / `.header(name)`.
- `pm.test(name, fn)`: a pass, or a failure with the thrown message. `pm.expect(value)`: chai-style `to`/`be`/`have`/`not`/`deep` chains with `equal`, `eql`, `include`, `property`, `a`/`an`, `above`, `below`, `least`, `most`, `within`, `oneOf`, `match`, `lengthOf`/`length`, and `ok`, `true`, `false`, `null`, `undefined`, `exist`, `empty`.
- `pm.info.eventName`, `console.log/info/debug/warn/error`.

Not in v1: `pm.sendRequest`, `pm.cookies`, `pm.globals`, `CryptoJS`, `lodash`, `moment`, `atob`/`btoa`, `postman.setNextRequest`. They may arrive later as Ruby host functions, never by loading arbitrary JS libraries.

## 5. Where scripts live and in which order

`pre_request_script`, `post_response_script`, `assertions` and `extractors` exist on `Collection`, `Folder` and `ApiRequest`. Order, as in Postman:

1. Pre-request scripts: collection → folders (outermost first) → request. They see the saved request and may change variables and the request.
2. The request is built (variables resolved, script changes applied), sent, and the response read.
3. Post-response: scripts of collection → folders (outermost first) → request, then the **assertions**, then the **extractors**; what scripts and extractors wrote is stored in the environment once, at the end.

Assertions and extractors of the three levels are concatenated in that order (they are additive, not overriding; `Requests::Automation` builds the list). Folders and collections edit theirs in the *Tests for every request below* section of their edit dialog (not shown when creating or while placing a draft).

## 6. Variables and writeback

- `pm.environment.set` and extractors write to the **selected environment**, which is what makes `token` and `bookingId` chains work. A write needs `EnvironmentPolicy#update?`; without it, the write stays in memory for the run (so a member who cannot edit the environment still runs the chain, locally) and a warning is recorded. A key that already exists keeps its `secret` flag and value type; a new key created by a script is a plain variable (an extractor can mark it secret).
- Writes during a **run** (§8) live in a run-scoped layer first and are written back to the environment only if the run asks for it (*Persist variables*, default on for a single request send and **off** for a collection run, so a run never silently rewrites the environment).
- Validation: keys must match `Variable::KEY_FORMAT`; values are capped at 64 KB; at most 50 variable writes per script.

## 7. Data model

| Table / column | Notes |
|---|---|
| `api_requests`, `folders`, `collections`: `assertions` (jsonb `[]`), `extractors` (jsonb `[]`) (`api_requests` in phase 1, the others in phase 2); `pre_request_script`, `post_response_script` (text, phase 4) | Scripts capped at 64 KB, rows at 50 per level. One migration per change. |
| `request_executions`: `test_results` (jsonb `[]`; phase 1), `script_logs` (jsonb `[]`) and `script_error` (text) (phase 4) | Travel with the latest execution and history, masked. |
| `collection_runs` | `project`, `collection`, `folder` (optional), `user`, `environment` (optional), `status` (AASM: `queued → running → completed \| failed \| cancelled`), `total_count`, `passed_count`, `failed_count`, `options` (jsonb), `error`, `started_at`, `finished_at`. |
| `collection_run_items` | `collection_run`, `api_request` (nullable, the request may be deleted later), `request_name`, `http_method`, `position`, `status` (AASM: `pending → running → passed \| failed \| skipped`), `url` (masked), `http_status`, `duration_ms`, `test_results` (jsonb), `error_kind`, `error_message`. No bodies. |

Assertion row: `{ "id", "source", "target", "operator", "expected", "enabled" }`. The model (`TestAutomation`) drops rows with an unknown source or operator and rows missing what the choice needs (a target for `header`/`json`, a value for operators that compare), keeps at most 50 per level and clips `target` to 500 and `expected` to 1 000 characters.

Outcome (one per row, kept in `test_results`): `{ "kind" (assertion|extractor|script), "status" (passed|failed|warning), "source", "target", "operator", "expected", "actual", "error", "variable" }`. Outcomes carry keys, never sentences; the viewer's language builds the text (`AutomationHelper`). `actual` is masked and cut to 200 characters. A transport error has no response, so it yields no outcomes.

| `source` | `target` | Operators |
|---|---|---|
| `status` | – | `equals`, `not_equals`, `lt`, `gt`, `in_range` (`expected` = `200-299`) |
| `header` | header name | `exists`, `not_exists`, `equals`, `contains`, `matches` |
| `json` | JSONPath | `exists`, `not_exists`, `equals`, `not_equals`, `contains`, `matches`, `lt`, `gt`, `type` (`string number boolean array object null`), `length` |
| `body` | – | `contains`, `not_contains`, `matches`, `is_empty` |
| `time` | – | `lt` |
| `size` | – | `lt` |

Extractor row: `{ "id", "source": "json|header|status|body", "target", "variable", "secret", "enabled" }`. A missing value leaves the variable untouched and records a `warning` outcome (`not_found`), not a failure. A variable name the environment would reject (`Variable::KEY_FORMAT`) is a validation error on save.

`expected` supports `{{variables}}`, resolved with the same resolver as the request.

## 8. Collection runner

`CollectionRun` + `CollectionRunItem`, performed by `RunCollectionJob` (queue `executions`, one run per member at a time) through `ApiClient::Runs::Perform`.

- **Scope**: a whole collection or one folder (subfolders included), in the order the sidebar shows (`Runs::Scope`: for each container its subfolders recursively first, then its own requests). Entry points: *Run* and *Run history* in the collection menu, *Run* in the folder menu (any member of the project, even one who cannot manage the collection: running is read-level like sending a request).
- **Options** (the *Run requests* dialog, `GET /workbench/collections/:id/runs/new`): environment, *stop at the first failure*, delay between requests (0 to 10 000 ms), *save extracted values to the environment* (off by default).
- **Planning** (`Runs::Create`): one `pending` item per request with a snapshot of its name and method, so a request deleted later does not erase the report. Refuses an empty scope, more than `SHANGO_RUN_MAX_REQUESTS` requests (default 200) and a second run while the member has one queued or running (a run untouched for an hour no longer counts, so a crashed worker cannot block anyone forever). `POST /workbench/collections/:id/runs` is rate limited (`runs`, 10 per 10 minutes).
- **Execution**: one request at a time (a chain depends on order). Each goes through the regular `Requests::Dispatch` with `stash: false` (a run is not an editing session: it never writes to history or to `latest_executions`), the run's environment and a **run-scoped variable layer** (`variables:` and `secrets:`, on top of the environment's: what extractors find reaches the next requests, and secret values are masked in later items). With *save extracted values* on, `persist: true` also writes them to the environment (`VariableWriteback`, only when the member who started the run may edit it).
- **Items** are AASM-driven: `pending → running → passed | failed | skipped`. A request **fails** when it could not be sent (timeout, DNS, invalid URL, …) or any assertion failed; extractor warnings never fail it. A request without assertions passes when it got a response. A request whose record was deleted is skipped (`request_deleted`).
- **Run states** (AASM): `queued → running → completed | failed | cancelled`. `completed` means the run reached the end (check `failed_count` for failures); `failed` means it could not finish (`access_revoked` when the member left the project, `unexpected` for anything else, logged); `cancelled` is a cancel.
- **Cancelling** (`POST /workbench/runs/:id/cancellation`, the starter or an owner): `Runs::Cancel` cancels the run and skips its pending and running items at once; the job looks the status up before every request and passes it to the executor so the request in flight is aborted.
- **Live page** (`GET /workbench/runs/:id`): `turbo_stream_from` the run; `Runs::Perform` broadcasts a Turbo refresh after every request and on state changes (the same mechanism as Monitoring), with counts, a progress bar, one expandable row per request (status, method, HTTP status, time, the outcomes of its assertions and extractors, the masked URL) and *Run again* with the same options. `GET /workbench/collections/:id/runs` lists the last runs of a collection.
- **Reports** (`Runs::Report`, in the language of whoever downloads them): `GET /workbench/runs/:id.json` and `.xml` (JUnit: one suite per request, one case per assertion that ran, one for a request that could not be sent, a single passing case for a request without tests, `skipped` for requests that did not run; extractor warnings are not cases).
- **Retention**: `PruneCollectionRunsJob` (daily) deletes finished runs older than `SHANGO_RUN_RETENTION_DAYS` (default 30, `0` keeps them) and keeps at most the last 20 finished runs per collection.
- **Authorization**: `CollectionRunPolicy`: `show?` and `create?` for the project, `cancel?` for the starter or an owner while the run is active.

## 9. Import and export

- **Postman import**: `event` entries (`prerequest`, `test`) on the collection, its folders and its requests become their pre-request and post-response scripts (several events of a kind are joined). Calls Shango's `pm` does not have (`pm.sendRequest`, `pm.cookies`, `pm.globals`, `postman.*`, `CryptoJS`, `require()`, lodash `_`, `moment`, `xml2Json`, `tv4`, `atob`/`btoa`, …) do not stop the import: the script is kept as written and one warning per collection, folder or request names the calls (`Imports::Support.unsupported_apis`).
- **Bruno import**: `script:pre-request` is the pre-request script; `script:post-response` and `tests` make the post-response one. `Imports::BrunoScript` translates the calls that have a Postman twin (`bru.setVar/getVar/setEnvVar/getEnvVar`, `res.status`, `res.body`, `res.getStatus()`, `res.getBody()`, `res.getHeader()`, `res.responseTime`, `req.getUrl()`, `test(`, `expect(`); anything else (`req.setHeader`, `bru.runRequest`, …) is kept as written and reported like above.
- **Shango export and import** are lossless: scripts, assertions and extractors travel at every level.
- **Postman export** carries the scripts as `event` entries; the assertions and extractors become a generated block at the start of the `test` script (`Exports::AssertionScript`): one `pm.test` per assertion and a `pm.environment.set` per extractor. A JSONPath is translated only when it is a plain property path (`$.a.b[0]`, `$['a b']`); any other row is left in the script as a `// Not exported:` comment. A spec runs the generated script in Shango's own sandbox and checks it passes and fails the same rows as the evaluator does.
- **Insomnia and OpenAPI exports** have no equivalent and omit scripts, assertions and extractors.

## 10. Security checklist

- No filesystem, network, timers or module loading inside the sandbox; effects only through the closed host-function list.
- Time, memory and output limits (§3); a hostile script can waste at most its own timeout.
- Concurrency: scripts run inside `RunRequestJob` and `RunCollectionJob`; both are already throttled per user, and a project has one active run per user.
- Output masked (`Masker`) before storage and rendering; never logged server-side.
- Authorization on every action; everything scoped through the current project.
- Hostile input is part of the specs: infinite loops, memory bombs, deep recursion, giant strings, prototype pollution attempts, forged `pm` objects, invalid UTF-8.

## 11. Testing

100 % line and branch coverage (project rule). Evaluator and extractor are pure and table-driven; the sandbox has hostile-script specs; `Dispatch` has integration specs with pre/post scripts; the runner covers order, cancel, stop-on-failure, variable carry-over, limits and project isolation; every endpoint has authorization request specs; a system spec drives the editor and the runner; the seeded Restful-Booker project (`token`, `bookingId` chain) is the end-to-end fixture.

## 12. Delivery phases

Strings are written in `en` and `es` first (`config/locales/*/automation.*.yml`); the other locales are translated in phase 6.

| # | Phase | Status |
|---|---|---|
| 0 | Engine spike and this document | done |
| 1 | Assertions and extractors (migrations, evaluator, `Dispatch` integration, editor tabs, results tab) | done |
| 2 | Inheritance: assertions and extractors on folders and collections, with UI (scripts follow in phase 4) | done |
| 3 | Runner: models, job, UI, cancel, JSON/JUnit reports, retention | done |
| 4 | Scripts: sandbox, `pm` API, `Dispatch` integration, editors | done |
| 5 | Import and export with scripts | done |
| 6 | Hardening: ENV limits documented in [`operations.md`](operations.md), hostile-script specs, Docker build | pending |

The runner (3) ships before scripts (4) on purpose: it is useful with declarative assertions alone, and the risky part (running user code) lands last, on top of a runner that is already proven.
