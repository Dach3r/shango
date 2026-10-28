# Shango — Network Tools

> Design and reference for the Network Tools feature. **Status: built** (DNS checker with reverse DNS, port check, TCP ping, subnet calculator); **in progress** (the second wave in §2, built one tool at a time). Check the code for the details if something here looks out of date. Product context: [`product.md`](product.md). Technical conventions: [`architecture.md`](architecture.md). The outbound-request guard it reuses is described in [`api-client.md`](api-client.md) §6.

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
| **DNS checker** | Queries one record type for a domain against a fixed set of public resolvers and the domain's authoritative nameservers, in parallel. Shows each answer with its TTL, and (when an expected value is given) whether it matches, so the user sees how far a change has propagated. With the `PTR` type it takes an IP, queries its `in-addr.arpa` / `ip6.arpa` name and checks forward-confirmed reverse DNS: each name the PTR points to must resolve (`A` for IPv4, `AAAA` for IPv6) back to the same IP. |
| **Port check** | TCP connect check of a list or range of ports on one host. Reports `open`, `closed` (connection refused) or `filtered` (timeout), with the service name from a static table for well-known ports. |
| **TCP ping** | Opens a TCP connection to a host/port several times and reports per-attempt latency plus min/avg/max and loss. Answers "is it online". |
| **Subnet calculator** | For an IPv4 or IPv6 network typed with a prefix (`192.168.1.0/24`), a mask (`192.168.1.0 255.255.255.0`) or as a bare address: network, mask, wildcard, broadcast, first and last host, address and host counts and the kind of range (public, private, loopback, link-local); optionally the split into a longer prefix and whether an address is inside. Pure computation with `IPAddr`: no network access and no history. |

### Explicitly out of v1

- **nmap.** Not used and not a dependency: the Nmap Public Source License (NPSL 0.95) treats software built to run nmap and parse its output as a derivative work and forbids distributing it under plain GPL terms, which conflicts with the AGPL-3.0 license of Shango and the license rule in `CLAUDE.md`. Everything here uses the Ruby standard library. Do not add nmap, or any wrapper gem around it, without a license review.
- ICMP ping (needs raw sockets or the system `ping` binary and extra container capabilities), SYN/UDP scans, OS or service fingerprinting, scanning more than one host per run, CIDR ranges, traceroute.
- Saved checks with names, tags or sharing outside the project. Runs themselves are kept as history (see §3 and §10).
- Custom DNS resolvers entered by the user (it would turn the DNS checker into a way to talk to arbitrary internal servers).

### Second wave (in progress)

Planned in this order; each one ships with its service, page, locales, specs and an update of this document, and moves to *In v1* when built. All use only the Ruby standard library and reuse `SsrfPolicy`, `Destination`, `Parallel`, `Dns::Query` and the history.

| Tool | `kind` | What it does |
|------|--------|--------------|
| **TLS certificate** | `tls` | Handshake against the pinned IP with SNI, direct TLS or STARTTLS (SMTP, IMAP, POP3, chosen explicitly). Subject, issuer, SAN, validity, key, signature, chain, protocol, cipher, ALPN; trust and host match validated by hand so a bad certificate is reported, not an error. |
| **Email DNS health** | `email` | SPF (recursive lookup count, duplicates, `+all`/`?all`, `ptr`), DKIM (selectors typed after the domain), DMARC (`p`, `sp`, `pct`, `rua`) and MX, as a list of findings with severity. DNS only. |
| **Lookup** | `lookup` | Domain: RDAP through the IANA bootstrap (registrar, dates, status, nameservers, DNSSEC). IP: RDAP network data plus ASN through `origin.asn.cymru.com`. No personal data, only registrar and abuse contacts. |
| **HTTP check** | `http` | GET or HEAD, redirects followed by hand with every hop re-checked by `SsrfPolicy`; DNS, TCP, TLS and TTFB timings per hop; security headers analysis. No body, cookies or auth. |
| **Blocklist** | `blocklist` | An IP (or a domain through its A and MX) against a fixed set of DNSBLs whose terms allow this use (no Spamhaus); a list refusing the query is shown as `unavailable`, never as clean. |
| **DNS health** | `zone` | NS count and network diversity, SOA serial agreement, CAA, broken delegation, and full DNSSEC validation (DS ↔ DNSKEY and RRSIG signatures and validity). |

Whois over port 43 is not planned: RDAP replaces it with structured JSON over HTTPS.

The UI labels the third tool **TCP ping**, never plain "ping", so nobody mistakes it for ICMP.

## 3. User experience

- New project tool **Network** in `ToolsNav` (icon `radar`), live as soon as the first tool ships; it is rendered disabled with a *Soon* badge before that, like the other unbuilt tools.
- One page per tool, each with its own address: `/network` (DNS, the default), `/network/reverse_dns`, `/network/ports`, `/network/ping` and `/network/subnet`, served by `Network::WorkspacesController#show` (`network_workspace_path(kind)`; only the tool on display is rendered, so a page runs one history query). A saved run lives at `/network/checks/:id` (`Network::ChecksController#show`, same template): reloading or sharing the link shows the same tool with the stored result and what was typed. The page has three panes: an icon rail with the tools (`NetworkRail::Component`, plain links grouped by subject with a hairline between groups, `aria-current="page"` on the tool on display; the tools, their icons and groups come from `Network::Tools`, which also builds the route constraint; a tool can be a preset of another one, like *Reverse DNS*, which is the DNS page with `PTR` preselected and shares its history, and a saved run is shown under the most specific entry whose defaults match what was typed, `Network::Tools.for_run`), the history of that tool and the main area. The main area is a one-row form bar (fields have screen-reader labels only; the intro and hints sit under the bar) above the result. Below the `lg` breakpoint the rail turns into a top bar and the history goes under the main area.
- **History** is saved per user within a project (`NetworkCheck`, table `network_checks`); members never see each other's runs. Every successful run adds a row and answers with a `303` redirect to `/network/checks/:id`, so the address always points at the run on display (the history entry is marked with `aria-current`); failed runs (invalid input, blocked or unresolved targets) are not recorded and still answer with a Turbo Stream that fills the result area. The panel lists the newest runs of the tool (label, one-line summary, how long ago, a dot for `ok`/`warn`/`bad`); the page of a saved run shows its stored result through the same result partials as a live run and notes the previous run against the same target. Each entry has a delete button (`DELETE /network/checks/:id`, back to the tool) and the panel a *Clear* button (`DELETE /network/history?kind=dns`).
- **Variables in inputs.** Every text input of the tools gets the `{{variable}}` autocomplete and highlighting of the API Client (`variable-autocomplete` Stimulus controller, fed by `VariableAutocomplete#editor_variables`: enabled variables of the selected environment, secrets masked). The server resolves `{{…}}` (and the `{{$…}}` helpers) with `Network::Variables` in host, domain, expected value, ports, ping port and attempts; undefined variables and secret ones are refused with an error naming the variable. Port and attempts of the TCP ping are therefore text inputs (`inputmode=numeric`) validated on the server.
- Submitting posts to the tool's endpoint and the result replaces the result area as a Turbo Stream (same pattern as running a request in the API Client). The submit button uses the standard loading state. A saved run (`/network/checks/:id`) is read-only: the bar shows what was typed in non-editable fields (no form, no submit button) with a *New check* link back to the empty tool.
- The host/domain field accepts `{{variables}}` resolved from the member's selected environment (`ApiClient::VariableResolver`), the same way request URLs do. The resolved value is shown with the result.
- DNS tab fields: domain, record type (`A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SOA`, `CAA`), optional expected value, typed after the domain in the same input (`example.com 203.0.113.10`; split on the first whitespace, so a TXT value may contain spaces). Result: a propagation card (percentage of resolvers that match the expected value, or that answered when there is none, with a bar and the summary line, e.g. `7 of 9 resolvers match`), then a hairline grid with one cell per resolver (name, IP, answer(s), TTL, latency, status). Authoritative nameservers are listed in their own group because they are the source of truth: if they still return the old value, the change was never published.
- Ports tab fields: host, ports (`22,80,443` and/or ranges like `8000-8010`, or the preset *Common*). The bar shows only a preset select (*Common*, *Web*, *Mail*, *Databases*, *Custom*; `NetworkHelper#port_preset_options`, groups in `PortSpec::PRESETS`) that opens as a docked side panel like the DNS type. The real `ports` value is a hidden field; choosing a preset fills it, and *Custom* keeps the panel open and reveals a text input inside it (the `port-preset` Stimulus controller; the typed list also labels the select). A saved run shows the same select, disabled. Result: a verdict strip (target, open, filtered and closed counts), then one row per port with service, status and a latency bar, open ones first.
- Ping tab fields: host, port (default `443`), attempts (default 4, max 10). Result: summary, min/avg/max/loss figures and one line per attempt. A side column explains that it is a TCP ping and how to read the statuses.
- Line design, all text through i18n (`en` and `es`), colors from palette tokens. Statuses use `NetworkStatus::Component` (dot plus mono label).

## 4. Architecture

### Routes and controllers

Feature module `Network::` (controllers inherit `Network::BaseController < AuthenticatedController`, thin, plural REST names, one action per controller):

```ruby
namespace :network do
  root to: "workspaces#show"
  resources :dns_checks, only: :create
  resources :port_checks, only: :create
  resources :pings, only: :create
  resources :subnets, only: :create
end
```

| Route | Controller | Purpose |
|-------|------------|---------|
| `GET /network` | `Network::WorkspacesController#show` | Tabbed page |
| `POST /network/dns_checks` | `Network::DnsChecksController#create` | Run DNS check |
| `POST /network/port_checks` | `Network::PortChecksController#create` | Run port check |
| `POST /network/pings` | `Network::PingsController#create` | Run TCP ping |
| `POST /network/subnets` | `Network::SubnetsController#create` | Calculate a subnet (not saved, answers in place) |

Each `create` action: scope to `current_project`, declare strong params, call the service, respond with a Turbo Stream (the forms are Turbo forms; there is no HTML fallback). `Network::BaseController` throttles every POST per user with the `Throttling` concern (`throttle :network`, 20 per minute, override with `SHANGO_RATE_LIMIT_NETWORK=<count>/<seconds>`), and answers `429` as a Turbo Stream into the tool's result area. Each controller defines `result_target`.

### Services (`app/services/network/`, `Serviceable` + `Result`)

| Class | Responsibility |
|-------|----------------|
| `Network::Target` | Resolves `{{variables}}` against the selected environment (disabled variables are invisible, secret ones are refused), validates the host (hostname per RFC 1035 with `_` allowed, or IP literal; no scheme, path, port or whitespace) and returns the normalized host or an error. Shared by the three tools. |
| `Network::Destination` | Applies `Network::SsrfPolicy` to a host and returns the address probes connect to (`:blocked` / `:unresolved` errors). Used by port check and TCP ping. |
| `Network::Parallel` | `map(items, limit:)`: bounded threads, ordered results. |
| `Network::DnsChecks::Run` | Validates the record type and domain, builds the resolver list (authoritative first, then public), queries in parallel, evaluates the expected value, returns a `Result` whose `data` has the rows and the summary (`total`, `answered`, `matched`, `agree`). For `PTR` it requires an IP (`ptr_needs_ip` otherwise), queries `IPAddr#reverse` and adds `reverse` (the queried name) and `forward` to `data`. |
| `Network::DnsChecks::ForwardConfirmation` | Forward-confirmed reverse DNS: looks up `A` (IPv4) or `AAAA` (IPv6) of at most 3 names the PTR answers point to, through the lookup resolver, in parallel, and returns `{ name:, addresses:, confirmed: }` per name (addresses compared as `IPAddr`, so IPv6 notation does not matter). |
| `Network::Dns::Resolvers` | The fixed list of eight public resolvers (Google, Cloudflare, Quad9, OpenDNS, Verisign, AdGuard, CleanBrowsing, Lumen) and `authoritative(domain)`: asks `NS` for the name and every parent (except the TLD) in parallel and keeps the closest one that answers (a subdomain has no NS records of its own; an `ip6.arpa` name has up to 33 labels, so asking one by one took seconds), then looks up `A`, else `AAAA`, of each nameserver. Nameservers without address keep a nil `ip`. |
| `Network::Dns::Query` | One question to one nameserver. Always returns an `Answer` (`status`, `answers`, `ttl` = lowest TTL, `ms`); failures are statuses: `ok`, `cname` (only an alias came back), `nodata`, `nxdomain`, `servfail`, `refused`, `timeout`, `error`. Builds and decodes the message with `Resolv::DNS::Message`. |
| `Network::Dns::Transport` | The raw exchange: UDP first (connected socket, so replies from other sources are ignored), TCP with the 2-byte length frame when the reply is truncated. Raises `TimedOut` / `Failed`. |
| `Network::Dns::Row` | One table line (`name`, `ip`, `group`, `status`, `answers`, `ttl`, `ms`, `match`). |
| `Network::PortChecks::Run` | Parses the port spec, enforces limits, applies the SSRF policy, probes with bounded threads, returns rows sorted open first. |
| `Network::PortChecks::PortSpec` | Parses `22,80,8000-8010` and the `common` preset into a sorted unique integer list; rejects invalid or too many ports. |
| `Network::Pings::Run` | Applies the SSRF policy, performs N sequential probes, computes min/avg/max/loss. |
| `Network::Tcp::Probe` | One TCP connect with timeout, returns `{ status: :open/:closed/:filtered, ms: }`. Connects to the pinned IP. Closes the socket immediately; never sends or reads data. |
| `Network::Subnets::Calculate` | Parses the network (prefix, mask or bare address; `{{variables}}` resolved in every field), computes the range with `IPAddr` (IPv4 `/31` and `/32` count every address as a host, RFC 3021; IPv6 has no broadcast or mask), lists at most `MAX_SUBNETS` = 64 subnets of a longer prefix with the full count, and checks membership of an address (another IP version is outside). Errors: `blank_network`, `invalid_network`, `invalid_split`, `invalid_ip`. |
| `Network::Services` | Static port → service name table (`22 ssh`, `80 http`, `443 https`, `5432 postgresql`…). |

The DNS client speaks the protocol itself instead of using `Resolv::DNS#getresources` because that method swallows every error, so a timeout, an `NXDOMAIN` and an empty answer would look the same, and the propagation table needs to tell them apart. DNS does not use EDNS, so large answers (long `TXT` sets) arrive truncated over UDP and are fetched again over TCP.

Models: **`NetworkCheck`** (`network_checks`), one row per successful run, project-owned (`project_id` required; `user_id` and `environment_id` nullable with `on_delete: nullify`, so history outlives a user or environment). Columns: `kind` (`dns`, `ports`, `ping`; string enum with `CHECK`), `target` (resolved host), `outcome` (`ok`, `warn`, `bad`; string enum with `CHECK`), `input` (jsonb: what was typed, `{{variables}}` unresolved, values cut to 255 characters, so environment values never reach the table), `result` (jsonb: the plain data of the run) and `created_at`. Rows are immutable. Display text is never stored: the label, the one-line summary and the tone are derived at read time (`Network::Checks::Digest`, i18n keys of the result partials). Indexes: `[project_id, kind, created_at]` (history list) and `[project_id, kind, target, created_at]` (previous run). All reads go through `current_project.network_checks` filtered by `current_user`.

Services in `app/services/network/checks/`: `Record` (saves a run and trims the oldest beyond `NetworkCheck::KEEP_PER_KIND` = 50 per user, project and tool, in the same call; a failure to save is logged and never breaks the run), `Codec` (data of a run ↔ plain JSON: rows and attempts become hashes and are rebuilt as `Dns::Row`, `PortChecks::Row` and `Tcp::Probe::Attempt`; at most 10 answers of 255 characters per DNS row) and `Digest`. Both dispatch to one module per kind (`Codec::Dns`, `Digest::Ping`…) through a `KINDS` table with no fallback, so a new kind must register its own codec and digest; a spec checks that every `NetworkCheck` kind has both. Controllers: `Network::WorkspacesController` (`show`), `Network::ChecksController` (`show`, `destroy`) and `Network::HistoriesController` (`destroy`, clears one tool). `PruneNetworkChecksJob` (recurring, daily 3:45) deletes runs older than `SHANGO_NETWORK_HISTORY_RETENTION_DAYS` (90 by default, `0` keeps them).

UI: views under `app/views/network/` (one page template with the rail and one panel partial per tool, a shared `history` partial and `result` partial, one result partial per tool, shared `error`, `throttled` partials, `checks/_list` and `checks/_previous`) and `NetworkStatus::Component`, the badge for statuses (`open`, `timeout`, `mismatch`…, labels in `network.statuses`). `ToolsNav::ITEMS` has `{ key: :network, icon: "radar", path: :network_root_path }`. Locale files: `config/locales/en/network.en.yml` and `config/locales/es/network.es.yml`, plus `components.tools_nav.network` in `views.en.yml` / `views.es.yml` (same folders).

### Execution model

Everything runs **synchronously inside the web request** (unlike API Client requests, which run in a background job because they can take minutes), because the caps in §5 bound the worst case to a few seconds and no job/broadcast machinery is needed. The tradeoff: a slow run holds one Puma thread for up to the time in the table below. If the caps are ever raised (for example to scan 1000 ports), move the run to a Solid Queue job that broadcasts the result with Turbo Streams instead of raising the timeout.

DNS and port probes run on short-lived threads through `Network::Parallel.map(items, limit:)`, which keeps results in input order, caps concurrency and re-raises errors on join. Each thread owns its socket; nothing is shared between them.

## 5. Limits

| Limit | Value | Why |
|-------|-------|-----|
| DNS query timeout (per nameserver) | 3 s | A dead resolver must not stall the table |
| DNS worst-case run | ≈ 3 s + NS lookup 3 s (+ 3 s forward confirmation for `PTR`) | Queries are parallel |
| Forward confirmation (`PTR`) | 3 names | One `A`/`AAAA` query per name |
| Ports per run | 100 | Bounds duration and abuse |
| Port probe timeout | 1.5 s | Long enough for most internet RTTs |
| Port probe concurrency | 20 | Worst case 100 ports ÷ 20 × 1.5 s ≈ 7.5 s |
| Ping attempts | 1–10, default 4 | |
| Ping probe timeout | 2 s | Attempts run one after another; the run stops after 5 timeouts in a row, so a dead host costs at most 10 s |
| Hosts per run | 1 | No sweeping |
| Subnets listed by the calculator | 64 (the count is always shown in full; above 2^53 it is written as a power of two) | Keeps the page small |
| Rate limit | 20 runs per minute per user, all tools combined (the subnet calculator included, though it sends nothing) | Abuse protection (`throttle :network` in `Network::BaseController`) |
| History kept | 50 runs per user, project and tool, 90 days | Bounds the table; `NetworkCheck::KEEP_PER_KIND`, `SHANGO_NETWORK_HISTORY_RETENTION_DAYS` |

Planned limits for the second wave (confirmed per tool when it is built):

| Limit | Value |
|-------|-------|
| TLS handshake timeout (STARTTLS included) | 5 s, at most 4 KB read per protocol reply line |
| RDAP / bootstrap request | HTTPS only, 5 s, 1 MB body; IANA bootstrap cached 24 h |
| HTTP check | 10 redirects, 5 s per hop, GET or HEAD only, body discarded |
| DNSBL query | 3 s per list, parallel |
| SPF recursive lookups | 10 (the RFC 7208 limit) |

Values are constants in the services; they are not user settings.

## 6. Security

This feature makes the Shango server open connections to hosts the user names, so it is an SSRF and abuse surface. Rules:

1. **Reuse `Network::SsrfPolicy`** (`app/services/network/ssrf_policy.rb`, shared with the API Client) for port check and TCP ping. Same behavior and same switch: blocking private, loopback, link-local and cloud-metadata ranges is on by default in production and controlled by `SHANGO_BLOCK_PRIVATE_NETWORKS` (see [`api-client.md`](api-client.md) §6). The policy returns the address that was checked and the probe connects to **that** address (pinning), so DNS rebinding between check and connect is not possible. It was moved out of the `ApiClient` namespace for this feature; do not duplicate it.
2. **DNS checker is not an SSRF vector** because it only sends queries to the fixed public resolvers and to the authoritative nameservers listed in the domain's own `NS` records. Authoritative nameserver IPs go through the same `SsrfPolicy` check, otherwise a domain whose NS record points at `127.0.0.1` or `169.254.169.254` would make Shango send UDP packets inside the network.
3. **No user-supplied resolvers, no CIDR, one host per run, port cap** (§5), connect-only probes (no payloads, no banners), so the tools cannot be used to exploit services, only to check reachability.
4. **Rate limit** per user (§5).
5. **Audit log**: every port check and ping, refused ones included, logs one line: `[network] port_check user=<id> project=<id> input="<what was typed>" outcome=<ok or the error> host=<resolved host> ports=<count>` (`port=<n>` for pings). The typed input is cut to 100 characters and written with `inspect`, so newlines cannot forge log lines. Secret variables are rejected before anything runs, so no secret value can reach the log.
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
| Resolvers disagree | Answers shown per row; summary says `answers differ` (the propagation-in-progress case, or geo/load-balanced DNS); the tone stays `ok` while every resolver answered, `warn` only when some did not (or, with an expected value, some do not match) |
| `TXT` records longer than 255 bytes | Chunks joined before comparing |
| Trailing dots, case | Names compared case-insensitively without the trailing dot; `MX` compared as `priority host` |
| `PTR` with a host name instead of an IP | Form error `ptr_needs_ip` |
| Subnet: non-contiguous mask, prefix above 32/128, split not longer than the network | Form error (`invalid_network`, `invalid_split` with the valid range) |
| PTR name that does not resolve back to the IP | Row marked `unconfirmed` in the forward-confirmation section; no PTR answer at all shows a note instead |
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

## 9. How it was built

One logical commit per step, each with its specs and docs:

1. `📝 docs(network)` — this design, linked from `CLAUDE.md`, `product.md` and `architecture.md`.
2. `♻️ refactor(network)` — `SsrfPolicy` moved to `Network::SsrfPolicy`, no behavior change.
3. `✨ feat(network)` — `Network::Target` and `Network::Destination`; the *Network* entry in `ToolsNav` (disabled with a *Soon* badge until step 4).
4. `✨ feat(network)` — DNS checker: `Parallel`, `Dns::Transport`, `Dns::Query`, `Dns::Resolvers`, `DnsChecks::Run`, the page with its tabs, `BaseController` throttling, `NetworkStatus::Component`, entry made live.
5. `✨ feat(network)` — port check: `PortSpec`, `Services`, `Tcp::Probe`, `PortChecks::Run`, audit logging.
6. `✨ feat(network)` — TCP ping: `Pings::Run`.

The DNS checker came first because it is the most useful and the safest (no connections to hosts the user names). Port check and ping only started after the guard was shared (step 2).

Verification: RSpec at 100% line and branch coverage, rubocop and brakeman clean, and a manual run in the app with real DNS and TCP (DNS table for `example.com` and for a mid-change domain with an expected value, port table, ping, a blackhole address that stops after five timeouts in about ten seconds, and invalid input).

## 10. Open questions

- **Ownership verification** for port checks on public hosts (§6). Default proposed: none in v1.
- **Saved checks.** History is private to each user (§3). If teams want named, pinned or shared checks, add a `pinned` flag and a sharing rule on `network_checks`.
- **Link with Monitoring** (phase 3): a port or TCP check as a monitor type, reusing the same probe classes.
- **Link with AI** (phase 4): expose the tools as read-only tools to the assistant, with the same limits and policy.
- **ICMP ping** through the system `ping` binary, only if there is demand; needs `CAP_NET_RAW` or `net.ipv4.ping_group_range` in containers.
- **Resolver list.** Fixed list in code for v1; making it operator-configurable is cheap but not needed yet.
- **Cloud offering:** a managed Shango would scan from shared IPs, which changes the abuse analysis (ownership verification becomes mandatory).
- **DNSSEC through EDNS0.** `Resolv` (Ruby 4.0) has no DS, DNSKEY, RRSIG or OPT classes; those records arrive as `Resolv::DNS::Resource::Generic` and the DNS health tool parses them by hand and adds the OPT record (DO bit) itself. A spike confirms this before the tool is built.
