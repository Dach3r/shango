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

- **No ambient access.** The context has no `require`, filesystem, network, `eval`-to-host or timers. Every effect goes through a host function defined by `Scripting::Sandbox` from a closed list.
- **Limits per script** (ENV, with ceilings): `SHANGO_SCRIPT_TIMEOUT_MS` (default 2 000, max 10 000), `SHANGO_SCRIPT_MEMORY_MB` (default 32, max 128), console output capped at 64 KB, at most 100 tests and 200 log lines per run, test names cut to 200 characters.
- **Fresh context per script.** Nothing persists between scripts or runs except variables explicitly written.
- **Failures never crash a request.** A script error is recorded (`script_error`) and the request still goes out, unless it happened in a *pre-request* script, which aborts the run of that request with the message (the request never started). A timeout or out-of-memory is an ordinary script error.
- **Secrets.** A script can read secret variables, exactly as a request can already send them to a URL the member controls, so this is no new class of exposure. Everything a script produces (console, test names, failure messages) goes through `Masker` before it is stored or rendered.
- **Authorization.** Editing scripts, assertions and extractors needs `update?` on the request, folder or collection (creator or owner). Running only needs `execute?`.

## 4. The `pm` API (v1)

Subset of Postman's API, so imported scripts mostly work:

- `pm.environment.get(key)` / `set(key, value)` / `unset(key)`: reads and writes the selected environment (see §6 for persistence).
- `pm.variables.get/set/unset`: run-scoped variables, never persisted.
- `pm.request`: `url` (string), `method`, `headers` (`add`, `upsert`, `remove`, `get`), `body` (string). Mutable in *pre-request* scripts only.
- `pm.response`: `code`, `status`, `headers.get(name)`, `responseTime`, `text()`, `json()`. Only in *post-response* scripts.
- `pm.test(name, fn)`: records a pass, or a failure with the thrown message.
- `pm.expect(value)`: a small chai subset: `to.equal`, `eql`, `deep.equal`, `include`, `contain`, `have.property`, `be.a/an`, `be.above`, `be.below`, `be.oneOf`, `exist`, `be.true/false/null/undefined/empty`, `match`, `have.lengthOf`, negated with `.not`.
- `console.log/info/warn/error`.

Not in v1: `pm.sendRequest`, `pm.cookies`, `CryptoJS`, `lodash`, `moment`, `postman.setNextRequest`. They may arrive later as Ruby host functions, never by loading arbitrary JS libraries.

## 5. Where scripts live and in which order

`pre_request_script`, `post_response_script`, `assertions` and `extractors` exist on `Collection`, `Folder` and `ApiRequest`. Order, as in Postman:

1. Pre-request: collection → folders (outermost first) → request.
2. The request is built (variables resolved), sent, and the response parsed.
3. Post-response: collection → folders (outermost first) → request, then **assertions**, then **extractors** (collection → request), so a script can already see what extractors would set only by reading the response itself.

Assertions and extractors of the three levels are concatenated in that order (they are additive, not overriding).

## 6. Variables and writeback

- `pm.environment.set` and extractors write to the **selected environment**, which is what makes `token` and `bookingId` chains work. A write needs `EnvironmentPolicy#update?`; without it, the write stays in memory for the run (so a member who cannot edit the environment still runs the chain, locally) and a warning is recorded. A key that already exists keeps its `secret` flag and value type; a new key created by a script is a plain variable (an extractor can mark it secret).
- Writes during a **run** (§8) live in a run-scoped layer first and are written back to the environment only if the run asks for it (*Persist variables*, default on for a single request send and **off** for a collection run, so a run never silently rewrites the environment).
- Validation: keys must match `Variable::KEY_FORMAT`; values are capped at 64 KB; at most 50 variable writes per script.

## 7. Data model

| Table / column | Notes |
|---|---|
| `api_requests`, `folders`, `collections`: `assertions` (jsonb `[]`), `extractors` (jsonb `[]`) (`api_requests` in phase 1, the others in phase 2); `pre_request_script`, `post_response_script` (text, phase 4) | Scripts capped at 64 KB, rows at 50 per level. One migration per change. |
| `request_executions`: `test_results` (jsonb `[]`; phase 1), `script_logs` (jsonb `[]`) and `script_error` (text) (phase 4) | Travel with the latest execution and history, masked. |
| `collection_runs` | `project`, `collection`, `folder` (optional), `user`, `environment` (optional), `status` (AASM: `queued → running → completed \| failed \| cancelled`), `total`, `passed`, `failed`, `options` (jsonb), `started_at`, `finished_at`. |
| `collection_run_items` | `collection_run`, `api_request` (nullable, the request may be deleted later), `request_name`, `position`, `status`, `http_status`, `duration_ms`, `test_results` (jsonb), `script_logs` (jsonb), `error_kind`, `error_message`. No bodies. |

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

`CollectionRun` + `CollectionRunItem`, performed by `RunCollectionJob` (queue `executions`).

- Scope: a whole collection or one folder (subfolders included), in tree order (`Tree::Load`).
- Options: environment, *stop on first failure*, delay between requests (0–10 000 ms), *persist variables*.
- One request at a time (a chain depends on order); each goes through the regular `Requests::Dispatch` with a run-scoped variable layer and the scripts/assertions above. It never writes to history or to `latest_executions` (a run is not an edit session).
- A request **fails** if it has a transport error, a pre-request error, or any failed test/assertion. A request with no tests passes if it got a response.
- Cancelling is checked between requests and between response chunks (the `Executor` already polls a `cancelled` callable).
- Limits: `SHANGO_RUN_MAX_REQUESTS` (default 200 requests per run), one active run per user and project, runs older than the retention are deleted (`SHANGO_RUN_RETENTION_DAYS`, default 30; at most the last 20 per collection are kept).
- UI: *Run* on a collection or folder → options screen → live page (`turbo_stream_from`, a Turbo refresh after each item, same mechanism as Monitoring) with counts, one row per request, tests and logs on expand; JSON and JUnit XML reports (`/workbench/runs/:id.json|.xml`).
- Authorization: `CollectionRunPolicy`: show for the project, create needs `execute?` over the scope, cancel by the starter or an owner.

## 9. Import and export

- **Postman**: `event` entries (`prerequest`, `test`) on collection, folder and request become the scripts. Scripts that call APIs outside §4 import anyway and the `:scripts` warning names them (scanned by text), so the user knows what will fail.
- **Bruno**: `script:pre-request`, `script:post-response` and `tests` blocks. `bru.*` and `req.*`/`res.*` are translated only for the trivial calls (`bru.setEnvVar`, `bru.getEnvVar`, `res.status`, `res.body`, `test(...)`/`expect(...)`); the rest imports as text with the warning.
- **Postman and Shango export** carry the scripts and assertions (assertions become a generated `pm.test` block in Postman). Insomnia and OpenAPI export omit them with a warning.

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
| 2 | Inheritance: scripts, assertions and extractors on folders and collections, with UI | pending |
| 3 | Runner: models, job, UI, cancel, JSON/JUnit reports, retention | pending |
| 4 | Scripts: sandbox, `pm` API, `Dispatch` integration, editors | pending |
| 5 | Import and export with scripts | pending |
| 6 | Hardening: ENV limits documented in [`operations.md`](operations.md), hostile-script specs, Docker build | pending |

The runner (3) ships before scripts (4) on purpose: it is useful with declarative assertions alone, and the risky part (running user code) lands last, on top of a runner that is already proven.
