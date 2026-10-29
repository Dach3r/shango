# Shango — Monitoring

> Design and reference for the Monitoring module. **Status: in progress** — steps 1 to 4 of §12 are built: the models (`UptimeMonitor`, `CheckResult`, `CheckRollup`, `Incident`, `UptimeMonitorPolicy`; locale file `config/locales/<locale>/monitoring.<locale>.yml`), the state machine (`Monitoring::Checks::Apply` over the AASM `status`), `Checks::Perform`, `Checks::Run`, `Monitors::Dispatch`, `Pause`, `Resume`, `MonitoringDispatchJob` and `MonitorCheckJob`; and HTTP monitors of a typed URL (`Monitoring::Probes::Http`, `Monitoring::Guard`), TCP and SSL monitors (`Probes::Tcp`, `Probes::Ssl`, `Probes::Host`), the pages (`Monitoring::MonitorsController`, `Monitors::RunsController`, `Monitors::PausesController`, `Monitors::Create`, `Update`, `Overview`, `Report`, `Monitoring::Uptime`, `MonitorStatus` and `ResponseChart` components) and the live *Monitoring* entry of `ToolsNav`; and alerts by email, webhook, Slack and Discord (`NotificationChannel`, `MonitorChannel`, `NotificationDelivery`, `Monitoring::Notifications::*`, `NotificationDeliveryJob`, `MonitoringMailer`, `Monitoring::ChannelsController`). Results and deliveries are pruned by `PruneMonitoringJob`, and changes to monitors and channels are recorded as `AuditEvent`s. Push and domain monitors and monitors of a saved request are not built (§12 *Next*): `/monitoring/monitors/new` shows them with a *Soon* badge, and a kind without a probe gives `unknown` (`unsupported_kind`): the form only creates URL monitors, and a kind without a probe gives `unknown` (`unsupported_kind`). Built one step at a time (§12); check the code for the real state. Product context: [`product.md`](product.md) §9 (*Monitoring*, *Notifications*). Technical conventions: [`architecture.md`](architecture.md). It reuses the outbound guard of the API Client ([`api-client.md`](api-client.md) §6) and the probes of [`network-tools.md`](network-tools.md).

## 1. Goal

Know, without looking, whether the things a project depends on are up, and be told when they stop being up and when they recover. Today that means a separate service (StatusCake, Uptime Kuma, Better Stack) configured by hand with the same URLs, tokens and environments the project already has in Shango.

Monitoring is its own module, next to the API Client and Network, with its own entry in `ToolsNav` (`activity` icon, today disabled with a *Soon* badge). Network tools are one-off diagnostics run by a person; monitors are checks run by Shango on a schedule, with history, incidents and alerts.

## 2. Scope

### In v1

| Kind | `kind` | Checks | Down when |
|------|--------|--------|-----------|
| **HTTP** | `http` | A URL (method `GET` or `HEAD`, typed with `{{variables}}`) or a saved API Client request (any method, headers, body and auth, run as saved) | No answer, a status outside the expected ones (default `200-399`), or slower than the optional response-time limit |
| **TCP port** | `tcp` | A TCP connect to `host:port` (connect only, like the port check) | Refused or timed out |
| **SSL certificate** | `ssl` | The certificate of `host:port` (direct TLS) | Untrusted, wrong host name, expired, no certificate, or fewer days left than the threshold (default 14) |
| **Domain expiry** | `domain` | The registration of a domain through RDAP | Expired, fewer days left than the threshold (default 30), on hold or pending delete. A registry that does not answer is *unknown*, never down |
| **Push (heartbeat)** | `push` | Nothing is sent: a job, cron or backup calls a secret Shango URL each time it runs | No call within the interval plus a grace period |

Alerting: notification channels per project, of kind **email**, **webhook** (signed JSON), **Slack** and **Discord** (their incoming-webhook URLs). A monitor alerts the channels attached to it when an incident opens and when it resolves.

### Out of v1 (later, in this order of likely value)

- Maintenance windows (pause alerts on a schedule), reminders while an incident stays open.
- Public status pages and email reports.
- Body checks (keyword present or absent, JSON assertions). v1 reads the status, headers and timings only.
- Checks from several locations. Shango runs on one server, so every check comes from it; a down result is confirmed by retrying (§4), not by a second region.
- Page speed, server (agent) metrics, SMS, bulk insert/update, tags. Grouping by `Service` waits for the `Service` model.
- Live updates over Action Cable (see §11).

## 3. User experience

- Routes: `/monitoring` (list), `/monitoring/monitors/new`, `/monitoring/monitors/:id` (and `/edit`), `POST /monitoring/monitors/:id/run` (*Run now*: enqueues a check; shares the `network` rate limit; refused for a paused monitor), `POST` / `DELETE /monitoring/monitors/:id/pause` (pause, resume). Changing, running, pausing and deleting need `UptimeMonitorPolicy#update?`, `run?`, `pause?`, `destroy?` (creator or owner).
- `/monitoring` (`Monitoring::MonitorsController#index`): a summary bar (monitors in use against the project limit, up, down, paused, and the uptime of the last 24 hours across all of them), filters by status and kind, a search by name or target, and one card per monitor in a grid (line design: square, hairline borders, no shadows): name and kind, a sparkline of the latest response times (inline SVG drawn on the server, no chart library), status, uptime of the last 24 hours, average response time, and actions (run now, pause or resume, edit, delete) shown only when the member may use them (`policy(monitor)`). The list and the page of a monitor refresh themselves every 60 s while the tab is visible (`refresh` Stimulus controller: a Turbo morph of the same URL). Filters are `?status=up|down|pending|paused` and `?q=` (name, URL or host).
- `/monitoring/monitors/:id`: uptime over 24 hours, 7 days and 30 days, average response time, a response-time chart of the last 24 hours, the incidents (open first, then the latest ones), and the latest checks with status, time and error.
- `/monitoring/monitors/new` first asks for the kind (`?kind=`; kinds whose probe is not built show a *Soon* badge); the form then has a hidden `kind`. `/monitoring/monitors/new` and `/edit`: name, kind (chosen on creation, not editable afterwards; the form shows only the fields of the kind and starts with its defaults, such as port 443 for SSL), environment (defaults to the member's selected one), interval, timeout, confirmations, the kind's own fields, and the channels to alert. An HTTP monitor chooses between *URL* and *Saved request*; the request picker lists the project's requests by collection.
- `/monitoring/channels` (`Monitoring::ChannelsController`, reached from the *Monitors* / *Alert channels* tabs at the top of both pages): the project's notification channels with their masked target, how many monitors alert them, the latest delivery (sent, sending or failed with its reason), *Send test* (`POST /monitoring/channels/:id/test`, shares the `network` rate limit) and, for webhooks, *New secret* (`POST /monitoring/channels/:id/secret`). `/monitoring/channels/new` first asks for the kind; email is offered only when SMTP is configured (`Shango::Mailing.enabled?`). A channel stores the language of its messages (`locale`, defaulting to the creator's). On edit a URL is never shown back: the field is blank with the masked URL as placeholder, and blank keeps it. A webhook's signing secret is shown once, on the page the creation or regeneration redirects to (the session carries only the channel id, never the secret).
- A push monitor shows its URL once after creation or regeneration (*Regenerate* for members who may manage it); afterwards only its last four characters.
- Every user-facing string goes through i18n in all supported locales. Statuses use one badge component with the existing tones.

## 4. How checks run

### Scheduler

A recurring Solid Queue task (`MonitoringDispatchJob`, every minute) calls `Monitoring::Monitors::Dispatch`. `config/recurring.yml` gets the task under `production:` and under a new `development:` key (only this task), so monitors run locally with `bin/dev`, which starts `bin/jobs`. Solid Queue already runs one instance per tick; the lock below only matters when a slow dispatch overlaps the next tick.

1. One statement claims the due monitors and moves them forward: `UPDATE uptime_monitors SET next_check_at = … WHERE id IN (SELECT id … WHERE enabled AND next_check_at <= now() + 5 s ORDER BY next_check_at LIMIT 500 FOR UPDATE SKIP LOCKED) RETURNING id, config_version`. The 5 s slack keeps a tick that fires a little early from skipping a whole minute.
2. `next_check_at` moves one interval forward from the planned time, so the schedule does not drift; when more than one interval was missed it restarts from now. A new monitor is checked right away (`Monitors::Create` enqueues its first check) and its next check is planned one interval later plus a random part of a minute (`Monitors::Schedule`), so many monitors created together do not fire in the same second. A change to what is checked does the same (`Monitors::Update`, only when `config_version` moved).
3. After that commit, `ActiveJob.perform_all_later` enqueues one `MonitorCheckJob(monitor_id, config_version)` per row. Jobs live in the separate queue database, so claim and enqueue cannot share a transaction; a crash between them loses one check, which is accepted.
4. The same pass marks push monitors overdue (`last_pinged_at` older than interval + grace) by enqueuing a check for them too; the check, not the dispatcher, decides the result (§4 *State*).

`MonitorCheckJob` runs on its own `monitoring` queue with `limits_concurrency to: 1, key: monitor id, on_conflict: :discard, duration: 2 × the longest check (≈ 2 minutes)`: a check that would overlap one still running is dropped, never queued to run late (Solid Queue blocks by default).

### Probes

`Monitoring::Checks::Run` runs the probe of the kind. Probes are reused, not duplicated:

| Kind | Probe |
|------|-------|
| `http` (URL) | `Monitoring::Probes::Http`: a pinned `Net::HTTP` client in the pattern of `Network::Rdap::Client` (address from `Network::Destination`, refused when `Monitoring::Guard.metadata?`, no proxy, `verify_mode` peer, `User-Agent: Shango monitor`), status line and headers only, the body never read; redirects followed by hand up to 10 with every hop re-checked by the guard; the timeout is one deadline for every hop; the response time is the whole run and the timings (DNS, TCP, TLS, first byte, through `ApiClient::Timing`) are those of the last hop. Causes: `environment_missing`, `unresolved_variable`, `secret_variable`, `invalid_url`, `unexpected_status` (detail: status and reason), `slow_response`, `invalid_redirect`, `redirect_loop`, `too_many_redirects`, `connection_refused`, `connection_timeout`, `tls_failed` (detail: OpenSSL's reason), `connection_failed`, `blocked`, `unresolved`, each worded under `monitoring.causes` |
| `http` (saved request) | `ApiClient::RequestBuilder` on the **saved** request (never a draft) with the monitor's environment and no user (so `{{$response…}}` references do not resolve), then `ApiClient::Executor` with two new options, `deadline:` (the monitor's timeout overrides `Built.timeout`, and the whole run, redirects and digest retry included, ends at it instead of `MAX_DURATION`) and `max_bytes:` (64 KB instead of 5 MB). Redirect, verify and auth settings are the request's own. An OAuth 2.0 token refresh writes to the request's `auth_config` exactly as a manual send does; a refresh that fails or a flow that cannot refresh unattended (authorization code without a refresh token) gives the cause `auth_failed` |
| `tcp` | `Monitoring::Probes::Tcp`: the host through `Probes::Host` (`{{variables}}` from the environment, secret ones refused, scheme and path stripped by `Network::Target`, then `Network::Destination` and the metadata refusal), then `Network::Tcp::Probe` against that address with the monitor's timeout. Open is up; closed is `connection_refused`, no answer `connection_timeout`; also `invalid_host`, `environment_missing` and the guard's causes |
| `ssl` | `Monitoring::Probes::Ssl`: the host through `Probes::Host`, then `Network::Tls::Handshake.call(ip:, port:, sni: host (none for an IP), protocol: "tls", timeout:)` (`Refused`, `TimedOut`, `Failed` map to `connection_refused`, `connection_timeout`, `tls_failed`). Then, in order: `no_certificate`, `untrusted_certificate` (`Network::Tls::Trust.check`, detail its reason), `hostname_mismatch` (`OpenSSL::SSL.verify_certificate_identity`), `certificate_not_yet_valid`, `certificate_expired`, `certificate_expiring` (fewer than `days_before` whole days left). The leaf's `not_after` goes on the outcome as `expires_at`, which `Apply` keeps on the monitor (`uptime_monitors.expires_at`, shown on the card and the page); `response_ms` is the handshake |
| `domain` | `Network::Lookups::Domain` (RDAP). Its interval is chosen among 6, 12 or 24 hours. `rdap_unavailable` and `no_rdap_service` give an *unknown* result |
| `push` | No probe: overdue (no ping within interval + grace) is down; a ping is up |

### State

All state changes of one monitor happen in `Monitoring::Checks::Apply`, inside `monitor.with_lock`, after the probe returned (the probe never runs inside the lock). Checks, *Run now*, push pings and overdue checks all go through it, so they cannot race.

- **Stale results are dropped.** Every job carries the monitor's `config_version` (incremented on every edit, pause and resume). If it changed since enqueueing, or the monitor is disabled, the result is discarded.
- **Statuses.** `status` is an AASM state machine (`pending`, `up`, `down`; events `go_up` from `pending` or `down`, `go_down` from `pending` or `up`, `restart` to `pending`; each event stamps `last_status_change_at`; assigning `status` directly raises). Whether the monitor runs is only `enabled` (the UI shows a disabled monitor as *Paused*). A result is `up`, `down` or `unknown`; `unknown` is stored (no rollup) but changes nothing. A kind whose probe is not built yet gives `unknown` (`unsupported_kind`).
- **Confirmations.** A `down` result increments `failures`; the monitor turns `down` only when `failures` reaches `confirmations` (default 2, 1 to 5). After a failure below the threshold the job schedules its own retry with `MonitorCheckJob.set(wait: 30.seconds)` (the dispatcher only ticks every minute), except `ssl` and `domain`, whose next check stays on their interval. An `up` result resets `failures`.
- **Transitions.** `pending → up`: silent. `pending → down` and `up → down`: open an `Incident` and alert. `down → up`: resolve it and alert. Pausing resets `failures` and resolves an open incident with the reason `paused`, without alerting. Resuming sets `status` to `pending` and `next_check_at` to now.

Each applied check writes one `CheckResult` and updates the hourly rollup (§5), `status`, `last_checked_at` and `last_status_change_at`. The confirmations damp flapping and there are no reminders in v1, so a monitor alerts at most once per transition.

**Variables.** A URL monitor resolves `{{variables}}` from its environment with `Network::Variables` (secret variables refused, as in Network Tools). A saved-request monitor may use secret variables and auth like the API Client; no response body is stored, and every stored or sent text (error detail, final URL) is masked with `ApiClient::Masker.new(built.secrets)`, which covers the environment's secrets and the auth strategy's credentials, query-string API keys included.

**Deleted references.** A monitor records whether it needs an environment (`environment_required`, set when saved with one) and, for a saved-request HTTP monitor, the request through `settings.mode = "request"`. When the request or environment is deleted the reference becomes null and the next check fails with `request_missing` / `environment_missing`, which opens an incident and alerts: a monitor never silently stops checking.

## 5. Domain model

The product calls them *monitors*; the model is **`UptimeMonitor`** because Ruby defines `::Monitor` (loaded by ActiveSupport), so a `Monitor` model would collide with it. This follows the `ApiRequest` precedent.

| Model (table) | Key columns | Notes |
|---|---|---|
| `UptimeMonitor` (`uptime_monitors`) | `project_id`, `creator_id` (nullify), `environment_id` (nullify), `environment_required`, `api_request_id` (nullify), `name`, `kind` (`http`, `tcp`, `ssl`, `domain`, `push`; immutable), `enabled`, `interval` (seconds), `timeout` (seconds), `confirmations`, `settings` (jsonb, validated per kind: `mode`, `url`, `http_method`, `expected_statuses`, `max_response_ms`, `host`, `port`, `days_before`, `grace`), `push_token_digest`, `status` (`pending`, `up`, `down`), `failures`, `expires_at` (certificate or domain, from the latest check that knew it), `config_version`, `next_check_at`, `last_checked_at`, `last_pinged_at`, `last_status_change_at` | Partial index on `next_check_at` where `enabled` (dispatcher); `[project_id, status]` (summary); partial unique index on `push_token_digest` where not null |
| `CheckResult` (`check_results`) | `uptime_monitor_id` (FK `ON DELETE CASCADE`), `status` (`up`, `down`, `unknown`), `response_ms`, `http_status`, `error` (key), `detail` (masked, cut to 255), `timings` (jsonb), `checked_at` | Append-only. Index `[uptime_monitor_id, checked_at]` (latest checks, sparkline) and a BRIN index on `checked_at` (retention). Pruned in batches after `SHANGO_MONITOR_RESULTS_RETENTION_DAYS` (30) |
| `CheckRollup` (`check_rollups`) | `uptime_monitor_id` (cascade), `hour`, `checks`, `failures`, `responses` (checks that got a response), `response_ms_sum`, `response_ms_max` | One row per monitor and hour, upserted in `Apply`. Feeds averages and sparklines without scanning results; kept 400 days |
| `Incident` (`incidents`) | `project_id`, `uptime_monitor_id` (cascade), `cause` (error key), `detail` (masked), `started_at`, `resolved_at`, `resolution` (`recovered`, `paused`) | At most one open per monitor (partial unique index on `uptime_monitor_id` where `resolved_at IS NULL`). **Uptime is computed from incident durations** over the window (24 h, 7 d, 30 d), not from result counts, so push monitors, retries and pruning do not skew it |
| `NotificationChannel` (`notification_channels`) | `project_id`, `creator_id` (nullify), `name`, `kind` (`email`, `webhook`, `slack`, `discord`; the `CHECK` has all four from the start), `enabled`, `locale`, `target` (encrypted: webhook URL or the email addresses), `signing_secret` (encrypted, webhooks; `whsec_` + 32 random bytes) | Webhook, Slack and Discord URLs carry the credential, so they are encrypted and never rendered back in full. 20 per project |
| `MonitorChannel` (`monitor_channels`) | `uptime_monitor_id` (cascade), `notification_channel_id` (cascade) | Unique pair |
| `NotificationDelivery` (`notification_deliveries`) | `notification_channel_id` (cascade), `incident_id` (cascade, null for tests), `event` (`incident_opened`, `incident_resolved`, `test`), `status` (`pending`, `sent`, `failed`), `attempts`, `error`, `sent_at` | Unique `[notification_channel_id, incident_id, event]`: one delivery per channel and transition. Pruned with the results |

Large child tables use database-level `ON DELETE CASCADE`, and the models declare `dependent: :delete_all` (never `:destroy`), so deleting a monitor with tens of thousands of results is one statement and never instantiates them. Settings outside the monitor's kind are dropped on save, numbers are cast, and the defaults of the kind are filled in (`UptimeMonitor::DEFAULTS`). `config_version` is bumped only when `enabled`, `interval`, `timeout`, `confirmations`, `settings`, `environment_id` or `api_request_id` change, never by the state updates of a check. All enums are string-backed with a `CHECK` constraint; one `create_table` per migration, referenced tables first. All reads go through `current_project`; jobs load by id and every record carries its project.

## 6. Notifications

Inside the `Apply` transaction that opens or resolves an incident, `Notifications::Plan` creates one `NotificationDelivery` row (`pending`) per enabled channel of the monitor; after commit, one `NotificationDeliveryJob` per row is enqueued (default queue, one job per delivery at a time). `Notifications::Deliver` sends it with the sender of the channel's kind and moves its AASM `status`: `deliver` to `sent`, or `give_up` to `failed` after 5 attempts or a failure retrying cannot fix (a 4xx other than 408 and 429, a blocked or invalid URL, no SMTP). Otherwise the job schedules its own retry after 10 s, 30 s, 2 min and 10 min, or what a `429` asks in `Retry-After` (up to an hour). A finished delivery is never sent again, so a retry never alerts twice. *Send test* creates a `test` delivery the same way. Checks never wait for a delivery.

The message carries the monitor name and kind, a safe description of the target (the URL as typed with `{{variables}}` unresolved, or the request's collection and name; never resolved values), the cause, the times and a link to the monitor.

| Kind | Delivery |
|------|----------|
| `email` | `MonitoringMailer`, up to 10 addresses per channel; only when SMTP is configured |
| `webhook` | `POST` JSON to an http(s) URL through the guard with the pinned address, 10 s, no redirects; headers `X-Shango-Event`, `X-Shango-Timestamp` and `X-Shango-Signature: sha256=<HMAC of "timestamp.body" with the channel's signing secret>`. Body: `event`, `text`, `sent_at`, `url`, `project {id, name}`, `monitor {id, name, kind, target}` and `incident {id, cause, cause_text, detail, started_at, resolved_at, duration_seconds}` (both `null` in a test) |
| `slack` | `POST {"text": …}` (the alert line, then `<url|Open in Shango>`; `&`, `<`, `>` escaped so a name cannot inject markup or mentions); the URL must be `https`, port 443, no user info, host exactly `hooks.slack.com`, path starting with `/services/` or `/triggers/` |
| `discord` | `POST {"content": …, "allowed_mentions": {"parse": []}}` (the alert line and the link, at most 2000 characters; no mentions, so `@everyone` in a name pings nobody; a `429` is retried after its `Retry-After`); `https`, port 443, no user info, host exactly `discord.com` or `discordapp.com`, path starting with `/api/webhooks/` |

Slack and Discord deliveries also go through the guard with the pinned address and never follow redirects (`Notifications::Post`, shared by the three URL kinds). Failures are recorded on the delivery (`error` key under `monitoring.delivery_errors`, short `detail`) and never carry the URL.

A receiver checks a webhook like this (Ruby; any language with HMAC-SHA256 works the same):

```ruby
expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, "#{request.headers["X-Shango-Timestamp"]}.#{request.raw_post}")
ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["X-Shango-Signature"]) # and reject timestamps older than a few minutes
```

## 7. Push endpoint

`GET` or `POST /monitoring/push/:token`, and `POST /monitoring/push` with the token in the `X-Shango-Push-Token` header for clients that can send one (`Monitoring::PushesController#create`, no session, CSRF skipped, answers `204` or `404`). The token is 32 random bytes (urlsafe base64); only its SHA-256 digest is stored. `filter_parameters` does not cover path segments, so request logging is silenced for `/monitoring/push/*` by a small middleware (the token would otherwise appear in `Started GET "/monitoring/push/<token>"`); reverse-proxy access logs are outside Shango and `operations.md` says so. Rate limited per token (`SHANGO_RATE_LIMIT_PUSH`, default 12 per minute) and per IP. A call goes through `Checks::Apply` as an `up` result; pings to a paused monitor are accepted and ignored.

## 8. Limits

| Limit | Value | Why |
|-------|-------|-----|
| Monitors per project | 50 (`SHANGO_MONITORS_PER_PROJECT`); optional install-wide cap `SHANGO_MONITORS_TOTAL` (unset: none) | Every monitor costs a check per interval from the operator's server |
| Interval | 1, 2, 5, 10, 15, 30 or 60 minutes; `domain` 6, 12 or 24 hours; push 1 minute to 7 days | The dispatcher runs every minute |
| Timeout | 1–30 s, default 10; it bounds the whole check, redirects and retries included | Bounds a worker thread |
| Confirmations | 1–5, default 2; retry 30 s after a failure (not for `ssl`, `domain`) | Damps blips |
| Redirects (URL monitors) | 10, each re-checked by the guard | |
| Body read (saved-request monitors) | 64 KB, discarded | Nothing is stored |
| Channels per monitor / per project | 10 / 20 | |
| Email addresses per channel | 10 | |
| Results kept | 30 days (`SHANGO_MONITOR_RESULTS_RETENTION_DAYS`, `0` keeps them); hourly rollups 400 days | ≈ 43 000 results per 1-minute monitor |

**Workers.** `config/queue.yml` has a dedicated worker for the `monitoring` queue, so checks always have threads of their own even while API Client runs (up to 120 s) or exports fill the shared `*` worker (which may also pick monitoring jobs). Its threads come from `SHANGO_MONITORING_THREADS` (default 5). A one-minute monitor whose check takes the full 10 s timeout keeps a thread busy a sixth of the time, so 5 threads cover about 30 such monitors at worst and many more in practice; `operations.md` documents the sizing for the whole install (the cap is per project, not per install).

## 9. Security

1. **Outbound guard.** Every probe and every webhook delivery goes through `Network::SsrfPolicy` on every check (not only when the monitor is saved) and connects to the address that was checked, as Network Tools and the API Client do. Monitors follow the same switch: with `SHANGO_BLOCK_PRIVATE_NETWORKS=false` (the default outside production) they can reach internal hosts, which is what a self-hoster monitoring internal services wants. Unattended paths are different from a person clicking, so cloud metadata addresses (`169.254.0.0/16`, `fd00:ec2::254`) are refused for monitors and deliveries **whatever the switch says**.
2. **Secrets.** Channel URLs and signing secrets use Active Record encryption and are never rendered back unmasked. Push tokens are stored as digests and kept out of the logs (§7). Saved-request monitors may use secret variables and auth; their values never reach `check_results`, incidents, notifications or logs (no bodies are stored; every stored text goes through the masker with `built.secrets`).
3. **Authorization** (Pundit, membership as subject): any member sees the project's monitors, incidents and channels and can create monitors and channels; changing, pausing, running, deleting a monitor or channel is for its creator or an owner (`manage?`), like collections and environments. Attaching a channel to a monitor needs the right to change the monitor only. Unauthorized actions are not rendered.
4. **Abuse.** The per-project and install-wide caps, the minimum interval and connect-only TCP probes bound what a member can make the server do. *Run now* shares the `network` rate limit.
5. **Audit.** Creating, changing (only when something changed), pausing, resuming and deleting a monitor, and creating, changing and deleting a channel, are recorded as `AuditEvent`s with the name in `metadata` (`Monitors::Create`, `Update`, `Pause`, `Resume`, `Destroy`; `Channels::Save`, `Destroy`), shown on the project's activity page.
6. **Project scope.** Monitors, results, incidents and channels belong to one project; a monitor can only reference a request, an environment and channels of its own project (validated).

## 10. Testing

RSpec at 100 % line and branch coverage. No real network: probes are stubbed at their boundary (`Destination`, `Tcp::Probe`, `Tls::Handshake`, WebMock for HTTP and webhooks, `Lookups::Domain`). The state machine (`Checks::Apply`) is tested directly for every transition, stale `config_version`, confirmations, `unknown` results and pause/resume. The dispatcher is tested against the database (claiming, the 5 s slack, drift, missed intervals, `SKIP LOCKED` with two connections). Time is frozen with `travel_to`.

## 11. Open questions

- **Live updates.** Broadcasting a card replacement after each check (Turbo Streams over Solid Cable) multiplies cable traffic by the open tabs; v1 re-fetches the index every 60 s. Revisit after real use.
- **Reminders and escalation** while an incident is open — wanted, but needs per-channel throttling first.
- **Internal targets as an owner-only option** instead of following the global switch.
- **Checks from several locations** would need agents; not before the cloud offering.
- **`Service` grouping** once the `Service` model exists.

## 12. Build plan

One logical commit per step, each with its specs (100 % line and branch), locales in every language, rubocop on the touched files, and this document updated (status line at the top, the step marked built). Migrations get real timestamps, one `create_table` each, referenced tables first; enums are string-backed with a `CHECK`; state machines use AASM.

### Built

1. `📝 docs(monitoring)` — this design.
2. `✨ feat(monitoring)` — models and migrations (`uptime_monitors`, `check_results`, `check_rollups`, `incidents`), validations per kind, policy, factories; AASM `status`.
3. `✨ feat(monitoring)` — `Checks::Apply`, `Perform`, `Run`, dispatcher, `Pause`/`Resume`, jobs, recurring task and queue worker.
4. `✨ feat(monitoring)` — HTTP monitors of a typed URL (`Probes::Http`, `Guard`), index/show/form, *Run now*, pause, the live `ToolsNav` entry.
5. `✨ feat(monitoring)` — notification channels (email, webhook), deliveries, *Send test* (below).
6. `✨ feat(monitoring)` — retention (`PruneMonitoringJob`, below).
7. `✨ feat(monitoring)` — audit events for monitors and channels (below).
8. `✨ feat(monitoring)` — Slack and Discord channels (below).
9. `✨ feat(monitoring)` — TCP and SSL monitors (below).

### Next, in this order

Alerts come first: a monitor nobody is told about is only useful to someone watching the page. Then the upkeep that must exist before real use, then the other kinds by value and risk; the saved-request probe is last because it changes the shared `ApiClient::Executor`.

**5. Notification channels: email and webhook, deliveries, *Send test*** — `✨ feat(monitoring)`. **Built.**

- Migrations: `create_notification_channels`, `create_monitor_channels`, `create_notification_deliveries` (§5). `kind` and `event` with `CHECK`s; deliveries unique on `[notification_channel_id, incident_id, event]` (a partial unique index where `incident_id IS NOT NULL`, tests are not deduplicated); `[notification_channel_id, created_at]` for *last failure*.
- Models: `NotificationChannel` (encrypted `target` and `signing_secret`, `has_secure_token`-style secret generated on create, validation per kind: up to 10 addresses for `email`, an `http(s)` URL of at most 2048 characters for `webhook`; limit 20 per project), `MonitorChannel` (same project on both sides, 10 per monitor), `NotificationDelivery` with an AASM `status` (`pending` → `sent` / `failed`; `retry` from `failed` to `pending`), `NotificationChannelPolicy` (same rules as monitors).
- Apply: when `transition` is `opened` or `resolved`, create one `pending` delivery per enabled channel inside the same transaction; `Checks::Perform` enqueues `NotificationDeliveryJob` for them after commit (`ActiveJob.perform_all_later`). The job is a no-op for a delivery already `sent`; `retry_on` with polynomial backoff, 5 attempts, then `failed` with the error key.
- Services: `Monitoring::Notifications::Message` (one value object: monitor name and kind, a safe target description, cause, times, link; built from the incident, never from resolved values), `Deliver` (dispatch by kind), `Senders::Email` (`MonitoringMailer#incident` and `#test`, text and HTML, localised in the recipient project creator's locale or `I18n.default_locale`), `Senders::Webhook` (pinned `Net::HTTP` through `Network::Destination` + `Monitoring::Guard`, 10 s, no redirects, no proxy, `X-Shango-Event`, `X-Shango-Timestamp`, `X-Shango-Signature: sha256=…` over `"timestamp.body"`; a non-2xx is a failure; the URL never logged), `Channels::Create`, `Update`, `SendTest` (a `test` delivery, rate limited with `network`).
- Pages: `/monitoring/channels` (`Monitoring::ChannelsController`, index/new/create/edit/update/destroy; `Channels::TestsController` for *Send test*), the webhook signing secret shown once with *Regenerate*, the URL masked afterwards (scheme, host and the last four characters), email offered only when `Shango::Mailing.enabled?`. The monitor form gets channel checkboxes; show lists the attached channels.
- Docs: §6 (verification snippet for the signature in the doc), `operations.md` (deliveries need SMTP for email).
- Specs: Apply creates deliveries only on transitions and only for enabled channels; the job's idempotency and retries; signature (known vector); guard refusal and the metadata address; masking of the URL in errors; mailer previews in every locale.

**6. Retention** — `✨ feat(monitoring)`. **Built.**

- `PruneMonitoringJob` in the pattern of `PruneNetworkChecksJob`: `check_results` older than `SHANGO_MONITOR_RESULTS_RETENTION_DAYS` (30, `0` keeps them), `check_rollups` older than 400 days, `notification_deliveries` with the same days as results; `in_batches(of: 1000).delete_all` on `checked_at` (BRIN) and `hour`. Incidents are kept (they are the uptime history).
- `config/recurring.yml`: every hour under `production:` (not in development).
- `operations.md`: the variable, the expected size (≈ 43 000 results per 1-minute monitor and 30 days, ≈ 200 bytes each), worker sizing with `SHANGO_MONITORING_THREADS`.

**7. Audit events for monitors and channels** — `✨ feat(monitoring)`. **Built.**

- New migration replacing `audit_events_kind_check` (never editing the old one) with the kinds `monitor_created`, `monitor_updated`, `monitor_deleted`, `monitor_paused`, `monitor_resumed`, `channel_created`, `channel_updated`, `channel_deleted`. `target` stays a user, so the monitor or channel name goes in `metadata` (`name`), like `email` today.
- Recorded by `Monitors::Create`, `Update` (only when something changed), `Pause`, `Resume`, the destroy path (moved to a `Monitors::Destroy` service) and the channel services.
- `AuditEventsHelper` passes `name:`; the page heading changes from team history to project activity in every locale. `architecture.md` §7 lists the new kinds.

**8. Slack and Discord channels** — `✨ feat(monitoring)`. **Built.** The kind `CHECK` already listed both, so no migration was needed.

- Kinds `slack` and `discord` on `NotificationChannel`, with the strict URL rules of §6 (scheme, port 443, no user info, exact host, path prefix).
- `Senders::Slack` (`{"text": …}`, mrkdwn link to the monitor) and `Senders::Discord` (`{"content": …}`, `allowed_mentions: {parse: []}` so a monitor name cannot ping `@everyone`); both share the pinned, no-redirect poster of the webhook sender. Discord `429` honours `retry_after` within the job's retries.
- Specs: every rejected URL shape; payload escaping of names with `<`, `&`, `@`.

**9. TCP and SSL monitors** — `✨ feat(monitoring)`. **Built.** The expiry date went to a new `expires_at` column instead of the result's `timings`, so the list shows it without reading results.

- `Probes::Tcp`: `Network::Destination` (guard + metadata refusal) then `Network::Tcp::Probe`; causes `unresolved`, `blocked`, `connection_refused`, `connection_timeout`.
- `Probes::Ssl`: `Network::Tls::Handshake` with `sni: host`, then `no_certificate`, `Network::Tls::Trust.check` (`untrusted_certificate`), `verify_certificate_identity` (`hostname_mismatch`), `certificate_expired`, and `certificate_expiring` when fewer than `days_before` days remain (detail: the expiry date). `response_ms` is the handshake time.
- `Checks::Run::PROBES` gains both; the form shows host, port and, for SSL, days before expiry. The card and show page display the expiry date of an SSL monitor (stored in the result's `timings` jsonb as `expires_at`, no new column).
- Specs: stubs at `Tcp::Probe` and `Tls::Handshake` (certificate fixtures generated in the spec), no quick retry for `ssl`.

**10. Push monitors and the push endpoint** — `✨ feat(monitoring)`; the endpoint is public, so it gets the closest security review.

- `Monitoring::PushesController#create` outside the authenticated namespace (`GET`/`POST /monitoring/push/:token`, `POST /monitoring/push` with `X-Shango-Push-Token`), CSRF skipped, `204` or `404` (same body and timing for unknown and paused), `rate_limit` per token digest and per IP (`SHANGO_RATE_LIMIT_PUSH`, 12/min).
- `Shango::Middleware::SilencePushLogs` inserted before `Rails::Rack::Logger` so the path never reaches the log; a request spec asserts the token is absent from the log output. `filter_parameters` gains `token`.
- `Monitors::Create` generates the token for `push` and shows it once (flash-free: rendered on the show page from a one-time `session` key); `Monitors::RegenerateToken` + `Monitors::TokensController#create`.
- Overdue detection: `Monitors::Dispatch` also claims push monitors whose `last_pinged_at` (or `created_at`) is older than interval + grace and enqueues a check; `Probes::Push` returns `down` (`no_ping`) when still overdue at run time, `up` otherwise. A ping goes through `Checks::Apply` as `up` and sets `last_pinged_at`.
- Docs: §7 and `operations.md` (proxy logs keep the token; prefer the header form).

**11. Domain expiry monitors** — `✨ feat(monitoring)`.

- `Probes::Domain` over `Network::Lookups::Domain` with the monitor's timeout as deadline: `domain_expired`, `domain_expiring` (fewer than `days_before`), `domain_on_hold` (`clientHold`/`serverHold`, `pendingDelete`); `rdap_unavailable`, `no_rdap_service` and a missing expiration event give `unknown`. The host is reduced to its registrable domain before the lookup.
- Intervals 6, 12, 24 h already validated; no quick retry. The card shows the expiry date (`timings.expires_at`).

**12. HTTP monitors of a saved request** — `✨ feat(api_client)` for the executor, then `✨ feat(monitoring)`.

- First commit, shared code: `ApiClient::Executor` gains `deadline:` (seconds, default `MAX_DURATION`; also caps `Built.timeout`) and `max_bytes:` (default today's 5 MB). Defaults keep the API Client's behaviour byte for byte; its existing specs must pass untouched, plus new ones for both options.
- Second commit: `Probes::Request` builds the **saved** request with `ApiClient::RequestBuilder` (monitor environment, no user), runs the executor with the monitor's timeout and 64 KB, discards the body, applies expected statuses and `max_response_ms`, masks every stored text with `ApiClient::Masker.new(built.secrets)`; causes `request_missing`, `environment_missing`, `auth_failed` (OAuth refresh failure or a flow that cannot refresh unattended), plus the HTTP ones. The form's *Saved request* mode with a picker grouped by collection; the safe target text is `collection / request`.
- Specs: secrets never reach `check_results`, incidents or notifications; a deleted request opens an incident.
