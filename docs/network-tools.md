# Shango — Network Tools

> Design and implementation plan for the Network Tools feature (DNS checker, port check, TCP ping). **Status: designed, not built.** Nothing here exists in the code yet; check the repo for the real state. Product context: [`product.md`](product.md). Technical conventions: [`architecture.md`](architecture.md). The outbound-request guard it reuses is described in [`api-client.md`](api-client.md) §6.

## 1. Why

When configuring a server a developer constantly needs quick answers about the network:

- Are we online? Does the host answer?
- Which ports are open from the outside?
- Did the DNS change propagate yet, and which resolvers still serve the old value?

Today that means hopping to `ping`, `nc`/`nmap` in a terminal, and sites like dnschecker.org. Network Tools puts those checks inside the project workspace, where the target host is usually already defined as an environment variable (`{{host}}`, `{{base_url}}`).

Fit with the product: this is the *DNS Tools* entry of *Future tools* in `product.md` §9, widened to the three checks above. It has no dependency on monitoring, AI, or SSH, so it can ship at any point after phase 1. Later it can feed those features (a port check becoming a monitor, results becoming AI context), but v1 does not build that.

## 2. Scope

### In v1

| Tool | What it does |
|------|--------------|
| **DNS checker** | Queries one record type for a domain against a fixed set of public resolvers and the domain's authoritative nameservers, in parallel. Shows each answer with its TTL, and (when an expected value is given) whether it matches, so the user sees how far a change has propagated. |
| **Port check** | TCP connect check of a list or range of ports on one host. Reports `open`, `closed` (connection refused) or `filtered` (timeout), with the service name from a static table for well-known ports. |
| **TCP ping** | Opens a TCP connection to a host/port several times and reports per-attempt latency plus min/avg/max and loss. Answers "is it online". |

### Explicitly out of v1

- **nmap.** Not used and not a dependency: the Nmap Public Source License (NPSL 0.95) treats software built to run nmap and parse its output as a derivative work and forbids distributing it under plain GPL terms, which conflicts with the AGPL-3.0 license of Shango and the license rule in `CLAUDE.md`. Everything here uses the Ruby standard library. Do not add nmap, or any wrapper gem around it, without a license review.
- ICMP ping (needs raw sockets or the system `ping` binary and extra container capabilities), SYN/UDP scans, OS or service fingerprinting, scanning more than one host per run, CIDR ranges, traceroute.
- Persisting results (no history, no saved checks, no new tables). See §10.
- Custom DNS resolvers entered by the user (it would turn the DNS checker into a way to talk to arbitrary internal servers).
- Whois, TLS certificate inspection, reverse DNS: natural follow-ups, separate decisions.

The UI labels the third tool **TCP ping**, never plain "ping", so nobody mistakes it for ICMP.

## 3. User experience

- New project tool **Network** in `ToolsNav` (icon `radar`), live as soon as the first tool ships; it is rendered disabled with a *Soon* badge before that, like the other unbuilt tools.
- One page, `/network`, with three tabs: *DNS*, *Ports*, *Ping* (`TabBar::Component`, tab kept in `?tab=`, default `dns`). Each tab is a compact form plus a result area.
- Submitting posts to the tool's endpoint and the result replaces the result area as a Turbo Stream (same pattern as running a request in the API Client). The submit button uses the standard loading state. Results are not stored, so a reload shows an empty form.
- The host/domain field accepts `{{variables}}` resolved from the member's selected environment (`ApiClient::VariableResolver`), the same way request URLs do. The resolved value is shown with the result.
- DNS tab fields: domain, record type (`A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SOA`, `CAA`), optional expected value. Result: summary line (`7 of 9 resolvers match`), then a table with one row per resolver (name, IP, answer(s), TTL, latency, status). Authoritative nameservers are listed in their own group because they are the source of truth: if they still return the old value, the change was never published.
- Ports tab fields: host, ports (`22,80,443` and/or ranges like `8000-8010`, or the preset *Common*). Result: table of ports with status and service name, open ones first, plus counts.
- Ping tab fields: host, port (default `443`), attempts (default 4, max 10). Result: one line per attempt and the summary.
- Line design, all text through i18n (`en` and `es`), colors from palette tokens. Statuses use `StatusBadge::Component`.

## 4. Architecture

### Routes and controllers

Feature module `Network::` (controllers inherit `Network::BaseController < AuthenticatedController`, thin, plural REST names, one action per controller):

```ruby
namespace :network do
  root to: "workspaces#show"
  resources :dns_checks, only: :create
  resources :port_checks, only: :create
  resources :pings, only: :create
end
```

| Route | Controller | Purpose |
|-------|------------|---------|
| `GET /network` | `Network::WorkspacesController#show` | Tabbed page |
| `POST /network/dns_checks` | `Network::DnsChecksController#create` | Run DNS check |
| `POST /network/port_checks` | `Network::PortChecksController#create` | Run port check |
| `POST /network/pings` | `Network::PingsController#create` | Run TCP ping |

Each `create` action: scope to `current_project`, declare strong params, call the service, respond with a Turbo Stream (HTML fallback renders the page). Controllers use Rails' built-in `rate_limit` (backed by Solid Cache) so no gem is needed.

### Services (`app/services/network/`, `Serviceable` + `Result`)

| Class | Responsibility |
|-------|----------------|
| `Network::Target` | Plain class. Resolves `{{variables}}` against the environment, validates the host (hostname per RFC 1035 or IP literal; no scheme, path, port or whitespace), returns the normalized host or an error. Shared by the three tools. |
| `Network::DnsChecks::Run` | Validates the domain and record type, builds the resolver list, queries in parallel, evaluates the expected value, returns a `Result` whose `data` has the per-resolver rows and the summary. |
| `Network::Dns::Resolvers` | Static list of public resolvers (Google `8.8.8.8`, Cloudflare `1.1.1.1`, Quad9 `9.9.9.9`, OpenDNS `208.67.222.222`, and a few more) and the lookup of the domain's authoritative nameservers (`NS` query, then `A`/`AAAA` of each). |
| `Network::Dns::Query` | One `Resolv::DNS` query against one nameserver with a hard timeout; returns normalized answers (type-specific string, TTL) or an error symbol (`:timeout`, `:servfail`, `:nxdomain`, `:refused`). |
| `Network::PortChecks::Run` | Parses the port spec, enforces limits, applies the SSRF policy, probes with a bounded thread pool, returns rows sorted by port. |
| `Network::PortChecks::PortSpec` | Parses `22,80,8000-8010` into a sorted unique integer list; rejects invalid or too many ports. |
| `Network::Pings::Run` | Applies the SSRF policy, performs N sequential probes, computes min/avg/max/loss. |
| `Network::Tcp::Probe` | One TCP connect with timeout, returns `{ status: :open/:closed/:filtered, ms: }`. Connects to the pinned IP. Closes the socket immediately; never sends or reads data. |
| `Network::Services` | Static port → service name table (`22 ssh`, `80 http`, `443 https`, `5432 postgresql`…). |

Models: **none in v1.** There is no persistence, so no migration and no project-owned table. Project scoping still applies through `current_project` (the environment used for variable resolution is `current_membership.current_environment`, which belongs to the project) and through audit logging (§6).

UI: `Network::` views under `app/views/network/`, with a ViewComponent for the shared result rows if it is reused three times (`NetworkResult::Component`), `ToolsNav::ITEMS` gets `{ key: :network, icon: "radar", path: :network_root_path }`. Locale files: `config/locales/network.en.yml` and `network.es.yml`, plus `components.tools_nav.network` in the existing component locale files.

### Execution model

Everything runs **synchronously inside the web request**, like the API Client, because the caps in §5 bound the worst case to a few seconds and no job/broadcast machinery is needed. The tradeoff: a slow run holds one Puma thread for up to the time in the table below. If the caps are ever raised (for example to scan 1000 ports), move the run to a Solid Queue job that broadcasts the result with Turbo Streams instead of raising the timeout.

DNS and port probes run in short-lived threads (`Concurrent::FixedThreadPool` ships with Rails through `concurrent-ruby`; plain `Thread` plus `Queue` is fine too). Each thread owns its socket or resolver; nothing is shared except the result collection, which is a `Concurrent::Array` or is filled after `join`.

## 5. Limits

| Limit | Value | Why |
|-------|-------|-----|
| DNS query timeout (per nameserver) | 3 s | A dead resolver must not stall the table |
| DNS worst-case run | ≈ 3 s + NS lookup 3 s | Queries are parallel |
| Ports per run | 100 | Bounds duration and abuse |
| Port probe timeout | 1.5 s | Long enough for most internet RTTs |
| Port probe concurrency | 20 | Worst case 100 ports ÷ 20 × 1.5 s ≈ 7.5 s |
| Ping attempts | 1–10, default 4 | |
| Ping probe timeout | 2 s | Worst case 10 × 2 s = 20 s: attempts run sequentially, so cap total at 10 s by stopping after 5 consecutive timeouts |
| Hosts per run | 1 | No sweeping |
| Rate limit | 20 runs per minute per user, all three tools combined | Abuse protection (`rate_limit` in `Network::BaseController`) |

Values are constants in the services; they are not user settings.

## 6. Security

This feature makes the Shango server open connections to hosts the user names, so it is an SSRF and abuse surface. Rules:

1. **Reuse `ApiClient::SsrfPolicy`** for port check and TCP ping. Same behavior and same switch: blocking private, loopback, link-local and cloud-metadata ranges is on by default in production and controlled by `SHANGO_BLOCK_PRIVATE_NETWORKS` (see [`api-client.md`](api-client.md) §6). The policy returns the address that was checked and the probe connects to **that** address (pinning), so DNS rebinding between check and connect is not possible. When this feature lands, move the class out of the `ApiClient` namespace (for example to `Networking::SsrfPolicy`, or keep it and reference it from `Network::`) in its own `♻️ refactor` commit; do not duplicate it.
2. **DNS checker is not an SSRF vector** because it only sends queries to the fixed public resolvers and to the authoritative nameservers listed in the domain's own `NS` records. Authoritative nameserver IPs go through the same `SsrfPolicy` check, otherwise a domain whose NS record points at `127.0.0.1` or `169.254.169.254` would make Shango send UDP packets inside the network.
3. **No user-supplied resolvers, no CIDR, one host per run, port cap** (§5), connect-only probes (no payloads, no banners), so the tools cannot be used to exploit services, only to check reachability.
4. **Rate limit** per user (§5).
5. **Audit log**: each port check and ping logs one line (`user_id`, `project_id`, resolved host, port count or port). No secrets are involved; environment variable values used to build the host are logged only as the resolved host, and if the variable is a secret the run is rejected (secret variables are not allowed in network targets).
6. **Project scope**: variables are resolved from the member's current environment of the current project only.
7. **No public exposure**: all endpoints sit behind `authenticate_user!`.

Open decision (see §10): require proof of ownership (DNS TXT or file) before port-checking a public host that is not in the project. Recommended default for v1: not required, because self-hosted installs run from the operator's own IP and the caps, rate limit and audit line limit damage; revisit before any managed cloud offering.

## 7. Error and edge cases

| Case | Behavior |
|------|----------|
| Host fails validation (scheme, path, spaces, empty) | Form error, nothing is sent |
| `{{variable}}` undefined, disabled, or secret | Form error naming the variable |
| Resolved IP is blocked by the policy | Result error `blocked`, with the same wording as the API Client |
| Host does not resolve | Port check / ping: error `unresolved`. DNS: `NXDOMAIN` shown per resolver |
| One resolver times out | That row shows `timeout`; the others still render; summary counts it as no answer |
| Expected value empty | No match column, summary shows only how many resolvers answered and whether answers agree with each other |
| Resolvers disagree | Answers shown per row; summary says `answers differ` (the propagation-in-progress case) |
| `TXT` records longer than 255 bytes | Chunks joined before comparing |
| Trailing dots, case | Names compared case-insensitively without the trailing dot; `MX` compared as `priority host` |
| Port spec invalid / above 65535 / more than 100 ports | Form error |
| IPv6-only host | Works; probes use the resolved address family |
| All probes time out | Port check: all `filtered`, with a hint that a firewall may drop packets; ping: `100% loss` |
| Rate limit hit | `429` with a localized message |

## 8. Testing

RSpec, 100% line and branch coverage like the rest of the app.

- **Services** (`spec/services/network/…`): no real sockets or DNS. Stub `Resolv::DNS` and `Socket.tcp` (WebMock does not intercept raw sockets or UDP) behind the small `Query` and `Probe` classes, so `Run` specs stub those two instead. Cover: each record type's normalization, timeout/NXDOMAIN/SERVFAIL, expected value match and mismatch, differing answers, port spec parsing (lists, ranges, duplicates, limits), SSRF blocked / unresolved, ping statistics and the consecutive-timeout stop.
- **`Network::Target`**: valid and invalid hosts, variable resolution, secret and disabled variables.
- **Requests** (`spec/requests/network/…`): auth required, each `create` happy path and error path as Turbo Stream, rate limit (use the null-store override already used in the suite or set a test cache store), project scoping of variables.
- **Components**: `ToolsNav` live entry, result component, status badges.
- Never run a real scan or DNS query in specs. A manual check against `localhost` and a public DNS name is part of the PR checklist.

## 9. Implementation plan

Each step is one logical commit with its specs and its docs update (per `CLAUDE.md`), run `bundle exec rubocop` on touched files first. Suggested commit subjects use the project's gitmoji convention.

1. `📝 docs(network): ...` — this document, linked from `CLAUDE.md`, `product.md` (§9 capability, §14 roadmap note) and `architecture.md` (§6 subsystem, §7 security).
2. `♻️ refactor(api_client): ...` — extract `SsrfPolicy` to a shared namespace, no behavior change, specs move with it.
3. `✨ feat(network): ...` — foundation: routes, `BaseController` with rate limit, workspace page with tabs, `Network::Target`, `ToolsNav` entry (live), locale files, specs. The tabs of tools not yet built render a *Soon* badge.
4. `✨ feat(network): ...` — DNS checker (`Dns::Resolvers`, `Dns::Query`, `DnsChecks::Run`, controller, tab, specs).
5. `✨ feat(network): ...` — port check (`PortSpec`, `Services`, `Tcp::Probe`, `PortChecks::Run`, controller, tab, specs).
6. `✨ feat(network): ...` — TCP ping (`Pings::Run`, controller, tab, specs).
7. `📝 docs(network): ...` — flip this document from *designed* to *built*, update `architecture.md` §9 snapshot, and add a short *Network Tools* paragraph to the user-facing docs.

Order matters: the DNS checker comes first because it is the most useful and the safest (no connections to user-chosen hosts). Steps 5 and 6 only start after the SSRF policy is shared (step 2).

Definition of done for the feature: all three tools usable from the UI in `en` and `es`, specs at 100% coverage, rubocop and brakeman clean, behavior verified manually in the running app, docs updated.

## 10. Open questions

- **Ownership verification** for port checks on public hosts (§6). Default proposed: none in v1.
- **History / saved checks.** If users want to compare a check over time, add a `network_checks` table (project-owned, one row per run, `kind` string enum with a `CHECK` constraint, JSON result). Decide after v1 is used.
- **Link with Monitoring** (phase 3): a port or TCP check as a monitor type, reusing the same probe classes.
- **Link with AI** (phase 4): expose the tools as read-only tools to the assistant, with the same limits and policy.
- **ICMP ping** through the system `ping` binary, only if there is demand; needs `CAP_NET_RAW` or `net.ipv4.ping_group_range` in containers.
- **Resolver list.** Fixed list in code for v1; making it operator-configurable is cheap but not needed yet.
- **Cloud offering:** a managed Shango would scan from shared IPs, which changes the abuse analysis (ownership verification becomes mandatory).
