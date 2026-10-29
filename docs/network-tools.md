# Shango — Network Tools

> Design and reference for the Network Tools feature. **Status: built** (DNS checker with reverse DNS, port check, TCP ping, TLS certificate, email DNS, lookup, subnet calculator); **in progress** (the second wave in §2, built one tool at a time). Check the code for the details if something here looks out of date. Product context: [`product.md`](product.md). Technical conventions: [`architecture.md`](architecture.md). The outbound-request guard it reuses is described in [`api-client.md`](api-client.md) §6.

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
| **DNS checker** | Queries one record type for a domain against a fixed set of public resolvers and the domain's authoritative nameservers, in parallel. Shows each answer with its TTL, and (when an expected value is given) whether it matches, so the user sees how far a change has propagated. With the `PTR` type (the domain placeholder switches to an IP address, `dns-type` Stimulus controller) it takes an IP, queries its `in-addr.arpa` / `ip6.arpa` name and checks forward-confirmed reverse DNS: each name the PTR points to must resolve (`A` for IPv4, `AAAA` for IPv6) back to the same IP. |
| **Port check** | TCP connect check of a list or range of ports on one host. Reports `open`, `closed` (connection refused) or `filtered` (timeout), with the service name from a static table for well-known ports. |
| **TCP ping** | Opens a TCP connection to a host/port several times and reports per-attempt latency plus min/avg/max and loss. Answers "is it online". |
| **TLS certificate** | Connects to one host and port, directly or after a STARTTLS dialog (SMTP, IMAP or POP3, chosen explicitly; a blank port takes the usual one: 443, 587, 143, 110), and reads the certificate and the session. Shows subject, issuer, names (SAN), validity, key, signature, serial, SHA-256 fingerprint, the chain as sent, protocol version, cipher and ALPN. Trust, host name and dates are checked by hand after a handshake that accepts any certificate, so a bad certificate is a result with findings (expired, not valid yet, expiring, name mismatch, self-signed, untrusted root, unknown issuer, old protocol, weak key, weak signature), not an error. |
| **Email DNS** | From the DNS alone, how a domain is set up for mail: SPF (the record, the DNS lookups it costs following `include` and `redirect` with the limit of 10, duplicates, `+all`/`?all`/missing `all`, `ptr`, loops and includes without a record), DKIM (the selectors typed after the domain, or a fixed list of common ones probed when none is typed; revoked, unreadable, short (under 2048 bits) and testing-mode keys), DMARC (`p`, `sp`, `pct`, `rua`, falling back to the parent domain's record) and MX (each server must resolve and must not be an alias; a null MX is understood). Shown as a status per part and one list of findings, worst first. Every question goes to one fixed public resolver, never to a server the domain names. Runs are kept in the history (kind `email`; the target is the domain, the tone the worst finding). |
| **Lookup** | Who is behind a domain or an IP address, from public registration data only. A domain: RDAP through the IANA bootstrap (registrar and its IANA id, registration, expiry and last-change dates with the days left, status codes, nameservers, DNSSEC signed or not, registrar abuse contact); a subdomain is resolved to its registered domain by dropping labels from the left (up to 3 names). An IP address: the network it belongs to and its holder from RDAP (name, handle, type, range, prefixes, country, the organization when the holder is one, abuse contact) plus the autonomous system that announces it from Team Cymru's IP-to-ASN mapping over DNS (up to 3 origins with name, prefix, country, registry and allocation date). No personal data is read: registrant, administrative and technical contacts are never looked at, and a holder that is a person is not named. The target is never contacted. Findings: expired, expiring (30 days), on hold, pending delete, network details or routing data missing, address not announced. Runs are kept in the history (kind `lookup`; the target is what was typed, the tone the worst finding). |
| **Subnet calculator** | For an IPv4 or IPv6 network typed with a prefix (`192.168.1.0/24`), a mask (`192.168.1.0 255.255.255.0`) or as a bare address: network, mask, wildcard, broadcast, first and last host, address and host counts and the kind of range (public, private, loopback, link-local); optionally the split into a longer prefix and whether an address is inside. Pure computation with `IPAddr`: no network access. Runs are kept in the history like the other tools (kind `subnet`; the target is the network in CIDR form, and a run whose address is outside is marked `warn`). |

### Explicitly out of v1

- **nmap.** Not used and not a dependency: the Nmap Public Source License (NPSL 0.95) treats software built to run nmap and parse its output as a derivative work and forbids distributing it under plain GPL terms, which conflicts with the AGPL-3.0 license of Shango and the license rule in `CLAUDE.md`. Everything here uses the Ruby standard library. Do not add nmap, or any wrapper gem around it, without a license review.
- ICMP ping (needs raw sockets or the system `ping` binary and extra container capabilities), SYN/UDP scans, OS or service fingerprinting, scanning more than one host per run, CIDR ranges, traceroute.
- Saved checks with names, tags or sharing outside the project. Runs themselves are kept as history (see §3 and §10).
- Custom DNS resolvers entered by the user (it would turn the DNS checker into a way to talk to arbitrary internal servers).

### Second wave (in progress)

Planned in this order; each one ships with its service, page, locales, specs and an update of this document, and moves to *In v1* when built. All use only the Ruby standard library and reuse `SsrfPolicy`, `Destination`, `Parallel`, `Dns::Query` and the history.

| Tool | `kind` | What it does |
|------|--------|--------------|
| **HTTP check** | `http` | GET or HEAD, redirects followed by hand with every hop re-checked by `SsrfPolicy`; DNS, TCP, TLS and TTFB timings per hop; security headers analysis. No body, cookies or auth. |
| **Blocklist** | `blocklist` | An IP (or a domain through its A and MX) against a fixed set of DNSBLs whose terms allow this use (no Spamhaus); a list refusing the query is shown as `unavailable`, never as clean. |
| **DNS health** | `zone` | NS count and network diversity, SOA serial agreement, CAA, broken delegation, and full DNSSEC validation (DS ↔ DNSKEY and RRSIG signatures and validity). |

Whois over port 43 is not planned: RDAP replaces it with structured JSON over HTTPS.

The UI labels the third tool **TCP ping**, never plain "ping", so nobody mistakes it for ICMP.

## 3. User experience

- New project tool **Network** in `ToolsNav` (icon `radar`), live as soon as the first tool ships; it is rendered disabled with a *Soon* badge before that, like the other unbuilt tools.
- One page per tool, each with its own address: `/network` (DNS, the default; reverse DNS is its `PTR` type), `/network/lookup`, `/network/ports`, `/network/ping`, `/network/tls`, `/network/email` and `/network/subnet`, served by `Network::WorkspacesController#show` (`network_workspace_path(kind)`; only the tool on display is rendered, so a page runs one history query). A saved run lives at `/network/checks/:id` (`Network::ChecksController#show`, same template): reloading or sharing the link shows the same tool with the stored result and what was typed. The page has three panes: an icon rail with the tools (`NetworkRail::Component`, plain links grouped by subject with a hairline between groups, `aria-current="page"` on the tool on display; the tools, their icons and groups come from `Network::Tools`, which also builds the route constraint), the history of that tool and the main area. The main area is a one-row form bar (fields have screen-reader labels only; the intro and hints sit under the bar) above the result. Below the `lg` breakpoint the rail turns into a top bar and the history goes under the main area.
- **History** is saved per user within a project (`NetworkCheck`, table `network_checks`); members never see each other's runs. Every successful run adds a row and answers with a `303` redirect to `/network/checks/:id`, so the address always points at the run on display (the history entry is marked with `aria-current`); failed runs (invalid input, blocked or unresolved targets) are not recorded and still answer with a Turbo Stream that fills the result area. The panel lists the newest runs of the tool (label, one-line summary, how long ago, a dot for `ok`/`warn`/`bad`); the page of a saved run shows its stored result through the same result partials as a live run and notes the previous run against the same target. Each entry has a delete button (`DELETE /network/checks/:id`, back to the tool) and the panel a *Clear* button (`DELETE /network/history?kind=dns`).
- **Variables in inputs.** Every text input of the tools gets the `{{variable}}` autocomplete and highlighting of the API Client (`variable-autocomplete` Stimulus controller, fed by `VariableAutocomplete#editor_variables`: enabled variables of the selected environment, secrets masked). The server resolves `{{…}}` (and the `{{$…}}` helpers) with `Network::Variables` in host, domain, expected value, ports, ping port and attempts; undefined variables and secret ones are refused with an error naming the variable. Port and attempts of the TCP ping are therefore text inputs (`inputmode=numeric`) validated on the server.
- Submitting posts to the tool's endpoint and the result replaces the result area as a Turbo Stream (same pattern as running a request in the API Client). The submit button uses the standard loading state. A saved run (`/network/checks/:id`) keeps the bar editable and filled with what was typed: submitting, changed or not, records a new run and moves to it, so there is no separate *New check* step (the rail link opens the empty tool).
- The host/domain field accepts `{{variables}}` resolved from the member's selected environment (`ApiClient::VariableResolver`), the same way request URLs do. The resolved value is shown with the result.
- DNS tab fields: domain, record type (`A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SOA`, `CAA`), optional expected value, typed after the domain in the same input (`example.com 203.0.113.10`; split on the first whitespace, so a TXT value may contain spaces). Result: a propagation card (percentage of resolvers that match the expected value, or that answered when there is none, with a bar and the summary line, e.g. `7 of 9 resolvers match`), then a hairline grid with one cell per resolver (name, IP, answer(s), TTL, latency, status). Authoritative nameservers are listed in their own group because they are the source of truth: if they still return the old value, the change was never published.
- Ports tab fields: host, ports (`22,80,443` and/or ranges like `8000-8010`, or the preset *Common*). The bar shows only a preset select (*Common*, *Web*, *Mail*, *Databases*, *Custom*; `NetworkHelper#port_preset_options`, groups in `PortSpec::PRESETS`) that opens as a docked side panel like the DNS type. The real `ports` value is a hidden field; choosing a preset fills it, and *Custom* keeps the panel open and reveals a text input inside it (the `port-preset` Stimulus controller; the typed list also labels the select). A saved run shows the same select, set to its ports. Result: a verdict strip (target, open, filtered and closed counts), then one row per port with service, status and a latency bar, open ones first.
- Ping tab fields: host, port (default `443`), attempts (default 4, max 10). Result: summary, min/avg/max/loss figures and one line per attempt. A side column explains that it is a TCP ping and how to read the statuses.
- TLS tab fields: host, port (text, `inputmode=numeric`, blank for the usual port of the protocol, which the `tls-protocol` Stimulus controller shows as the placeholder) and protocol (*Direct TLS*, *STARTTLS · SMTP*, *IMAP*, *POP3*). Result: a verdict strip (target with address, port and protocol; chain `trusted`/`untrusted`; host name `match`/`mismatch`; days left with `valid`, `expiring`, `expired` or `not_yet_valid`), the findings (worst first, a dot per tone, or *No problems found*), the certificate fields, its names, the connection (protocol, cipher, ALPN, SNI) and the chain as the server sent it. History label `host:port`, summary `Expires <date> · <TLS version>`; the tone is the worst finding (`bad` breaks clients, `warn` should be fixed).
- Email tab fields: one input with the domain and, after it, the DKIM selectors separated by spaces (`example.com selector1 selector2`; split on the first whitespace in the controller, up to 10 selectors, lowercase, letters, digits, `-`, `_` and dots). Result: a verdict strip (domain and one tile per part, SPF, DKIM, DMARC and MX, each `healthy`, `attention`, `broken` or `missing`, derived from the findings that start with its name by `NetworkHelper#email_section_status`), the findings (worst first, a dot per tone, or *No problems found*), then one section per part: the SPF record with its lookups against the limit and what it ends with, the DKIM selectors with key type and size (a note when the common ones were probed), the DMARC record with policy, subdomain policy, percentage and report addresses (and the domain it was found at when inherited) and the MX servers by preference with their state. History label `domain`, summary `<n> errors · <n> warnings` or *No problems found*; the tone is the worst finding.
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
  resources :tls_checks, only: :create
  resources :email_checks, only: :create
  resources :lookups, only: :create
end
```

| Route | Controller | Purpose |
|-------|------------|---------|
| `GET /network` | `Network::WorkspacesController#show` | Tabbed page |
| `POST /network/dns_checks` | `Network::DnsChecksController#create` | Run DNS check |
| `POST /network/port_checks` | `Network::PortChecksController#create` | Run port check |
| `POST /network/pings` | `Network::PingsController#create` | Run TCP ping |
| `POST /network/subnets` | `Network::SubnetsController#create` | Calculate a subnet |
| `POST /network/tls_checks` | `Network::TlsChecksController#create` | Inspect a TLS certificate |
| `POST /network/email_checks` | `Network::EmailChecksController#create` | Check the email DNS of a domain |
| `POST /network/lookups` | `Network::LookupsController#create` | Look up a domain or an IP address |

Each `create` action: scope to `current_project`, declare strong params, call the service, respond with a Turbo Stream (the forms are Turbo forms; there is no HTML fallback). `Network::BaseController` throttles every POST per user with the `Throttling` concern (`throttle :network`, 20 per minute, override with `SHANGO_RATE_LIMIT_NETWORK=<count>/<seconds>`), and answers `429` as a Turbo Stream into the tool's result area. Each controller defines `result_target`.

### Services (`app/services/network/`, `Serviceable` + `Result`)

| Class | Responsibility |
|-------|----------------|
| `Network::Target` | Resolves `{{variables}}` against the selected environment (disabled variables are invisible, secret ones are refused), validates the host (hostname per RFC 1035 with `_` allowed, or IP literal; `http(s)` scheme, path, query and fragment of a pasted URL are dropped; ports and whitespace are rejected) and returns the normalized host or an error. Shared by the three tools. |
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
| `Network::TlsChecks::Run` | Validates protocol (`tls`, `smtp`, `imap`, `pop3`), host and port (blank takes `DEFAULT_PORTS`), applies the SSRF policy, runs the handshake with SNI (none for an IP literal) and builds the result: `session`, `certificate` (with `validity` and `days_left`), `chain` (at most 10), `trust`, `host_match` (`OpenSSL::SSL.verify_certificate_identity`, wildcards and IP SANs included) and `findings`. A certificate is `expiring` with less than 14 days left, or less than a third of its lifetime for short-lived ones (when ACME clients renew). Errors: `invalid_protocol`, `invalid_port`, `connection_refused`, `connection_timeout`, `starttls_refused`, `handshake_failed` (with OpenSSL's reason), `no_certificate`. |
| `Network::TlsChecks::Findings` | The list of findings, worst first: `{ key:, tone:, args: }` with the key under `network.tls.findings`, so no display text is stored. Old protocols are SSLv3, TLS 1.0 and 1.1; weak keys are RSA under 2048 bits and EC under 224; weak signatures use MD2, MD5 or SHA-1. |
| `Network::EmailChecks::Run` | Validates the domain (no IP literal) and the selectors, refuses a domain that does not exist, then runs the four parts in parallel and joins their findings, worst first. The result is `host`, `spf`, `dkim`, `dmarc`, `mx` (each part's data, `nil` when its record is missing) and `findings`. |
| `Network::Dns::Lookup` | The DNS questions of the tools that read records (email DNS, and the ASN lookup): always `Dns::Query` against `Dns::Resolvers::LOOKUP_IP` (3 s), never a server named by the domain. Tells a resolver that failed (`timeout`, `servfail`, `refused`, `error`) from a record that is not there, and accepts only well-formed names read from records. |
| `Network::EmailChecks::Spf` | Finds the SPF record, follows `include` and `redirect` (cached, prefetched in parallel, depth 10, given up past 20 lookups, macros not followed) to count lookups and read the final `all`. Findings: `missing`, `multiple`, `too_many_lookups`, `loop`, `include_missing`, `lookup_failed`, `no_all`, `pass_all`, `neutral_all`, `ptr`. |
| `Network::EmailChecks::Dkim` | Reads `<selector>._domainkey.<domain>` for the typed selectors, or probes 15 common ones and keeps only those found. Reads the RSA key size with OpenSSL (`ed25519` has no size to report). Findings: `selector_missing`, `lookup_failed`, `revoked`, `invalid_key`, `weak_key` (under 1024 bits an error, under 2048 a warning), `testing`, `none_found`. |
| `Network::EmailChecks::Dmarc` | Reads `_dmarc.<domain>` and the same name of each parent domain, taking the first record. Findings: `missing`, `multiple`, `lookup_failed`, `invalid_policy`, `policy_none`, `weak_subdomain_policy`, `partial`, `no_reports`. |
| `Network::EmailChecks::Mx` | Lists up to 10 servers by preference and resolves each (`A`, then `AAAA`). Findings: `missing`, `lookup_failed`, `cname`, `unresolved`; a null MX (`0 .`) is understood. |
| `Network::EmailChecks::Tags`, `Section` | The `tag=value;` syntax of DKIM and DMARC records; the `{ data:, findings: }` each part returns. |
| `Network::Lookups::Run` | Resolves the target with `Target`, refuses private and reserved addresses, and hands a domain to `Domain` and an IP (IPv4-mapped IPv6 turned into IPv4) to `Address`, with a 10 s deadline for the whole run. The result is `host`, `type` (`domain` or `ip`), `domain`, `network`, `asn` and `findings`. |
| `Network::Lookups::Domain` | Finds the RDAP server of the TLD, asks for the typed name and then for its parents (404 means try the next), and reads dates, registrar, abuse contact, statuses, nameservers and DNSSEC. Findings: `expired`, `expiring`, `hold`, `pending_delete`. |
| `Network::Lookups::Address` | Asks RDAP (network and holder) and `Asn` in parallel; either may be missing, the run fails only when both are. Findings: `rdap_failed`, `asn_unavailable`, `not_announced`. |
| `Network::Lookups::Asn` | Team Cymru's `origin.asn.cymru.com` / `origin6.asn.cymru.com` mapping and `AS<n>.asn.cymru.com` names, through `Dns::Lookup`. |
| `Network::Lookups::Entities`, `Clean` | The only reader of RDAP `entities` (registrar, abuse, organization) and the text and date cleaner for everything read from outside. |
| `Network::Rdap::Client` | One JSON document over HTTPS: guard and pinned address on every hop, 5 s, shared deadline, 1 MB, 3 redirects, HTTPS only. Returns the document or `not_found` / `unavailable`. |
| `Network::Rdap::Bootstrap` | The RDAP base URL for a TLD (`dns.json`) or the most specific network that holds an address (`ipv4.json`, `ipv6.json`), cached 24 h in `Rails.cache`; `no_rdap_service` when none is listed over HTTPS. |
| `Network::Tls::Handshake` | The raw exchange: TCP connect to the pinned IP, `StartTls` when asked, then a non-blocking handshake that accepts any certificate (`VERIFY_NONE`, TLS 1.0 and security level 0 allowed, so weak servers are reported rather than refused) and offers ALPN `h2, http/1.1` on direct TLS only. One deadline for every step. Returns `Session` (`version`, `cipher`, `bits`, `alpn`, `chain`); raises `Refused`, `TimedOut`, `Failed`. |
| `Network::Tls::StartTls` | The plain-text upgrade: SMTP (`EHLO shango.invalid`, `STARTTLS` must be offered), IMAP (`a1 STARTTLS`), POP3 (`STLS`). Reply lines are cut at 4 KB; anything unexpected raises `Refused`. |
| `Network::Tls::Certificate` | An `OpenSSL::X509::Certificate` as plain data (CN or O or the whole DN, SANs of type DNS and IP up to 100 with the full count, ISO 8601 dates, key type and size or curve, signature algorithm, serial, SHA-256 fingerprint) and the one-line summary of each certificate of the chain. |
| `Network::Tls::Trust` | Verifies the chain against the system roots (`OpenSSL::X509::Store#set_default_paths`) with `V_FLAG_NO_CHECK_TIME`, so dates are reported on their own, and purpose `sslserver`. Reasons: `self_signed`, `untrusted_root`, `unknown_issuer` (missing intermediate or unknown CA), `other` with the OpenSSL code. |
| `Network::Subnets::Calculate` | Parses the network (prefix, mask or bare address; `{{variables}}` resolved in every field), computes the range with `IPAddr` (IPv4 `/31` and `/32` count every address as a host, RFC 3021; IPv6 has no broadcast or mask), lists at most `MAX_SUBNETS` = 64 subnets of a longer prefix with the full count, and checks membership of an address (another IP version is outside). Errors: `blank_network`, `invalid_network`, `invalid_split`, `invalid_ip`. |
| `Network::Services` | Static port → service name table (`22 ssh`, `80 http`, `443 https`, `5432 postgresql`…). |

The DNS client speaks the protocol itself instead of using `Resolv::DNS#getresources` because that method swallows every error, so a timeout, an `NXDOMAIN` and an empty answer would look the same, and the propagation table needs to tell them apart. DNS does not use EDNS, so large answers (long `TXT` sets) arrive truncated over UDP and are fetched again over TCP.

Models: **`NetworkCheck`** (`network_checks`), one row per successful run, project-owned (`project_id` required; `user_id` and `environment_id` nullable with `on_delete: nullify`, so history outlives a user or environment). Columns: `kind` (`dns`, `ports`, `ping`, `subnet`, `tls`, `email`, `lookup`; string enum with `CHECK`, replaced by one migration per new kind), `target` (resolved host, or the network for `subnet`), `outcome` (`ok`, `warn`, `bad`; string enum with `CHECK`), `input` (jsonb: what was typed, `{{variables}}` unresolved, values cut to 255 characters, so environment values never reach the table), `result` (jsonb: the plain data of the run) and `created_at`. Rows are immutable. Display text is never stored: the label, the one-line summary and the tone are derived at read time (`Network::Checks::Digest`, i18n keys of the result partials). Indexes: `[project_id, kind, created_at]` (history list) and `[project_id, kind, target, created_at]` (previous run). All reads go through `current_project.network_checks` filtered by `current_user`.

Services in `app/services/network/checks/`: `Record` (saves a run and trims the oldest beyond `NetworkCheck::KEEP_PER_KIND` = 50 per user, project and tool, in the same call; a failure to save is logged and never breaks the run), `Codec` (data of a run ↔ plain JSON: rows and attempts become hashes and are rebuilt as `Dns::Row`, `PortChecks::Row` and `Tcp::Probe::Attempt`; subnet and TLS data are stored as is (TLS data is plain JSON from the start: strings, numbers and dates in ISO 8601), subnet counts included even when they exceed 64 bits; at most 10 answers of 255 characters per DNS row) and `Digest`. Both dispatch to one module per kind (`Codec::Dns`, `Digest::Ping`…) through a `KINDS` table with no fallback, so a new kind must register its own codec and digest; a spec checks that every `NetworkCheck` kind has both. Controllers: `Network::WorkspacesController` (`show`), `Network::ChecksController` (`show`, `destroy`) and `Network::HistoriesController` (`destroy`, clears one tool). `PruneNetworkChecksJob` (recurring, daily 3:45) deletes runs older than `SHANGO_NETWORK_HISTORY_RETENTION_DAYS` (90 by default, `0` keeps them).

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
| TLS handshake (connect, STARTTLS and handshake together) | 5 s, at most 4 KB per STARTTLS reply line | One deadline for every step |
| Email DNS: selectors, MX servers, SPF lookups | 10 typed selectors, 10 MX servers, SPF followed up to depth 10 and given up past 20 lookups; 3 s per DNS question | Bounds the queries one run can make |
| Lookup: RDAP and bootstrap requests | HTTPS only, 5 s each, 10 s for the whole run, 1 MB body, 3 redirects (each re-checked by the guard), IANA bootstrap cached 24 h; 3 registered-domain candidates, 3 ASN origins, 20 nameservers and statuses kept | Bounds the time and the size of what a registry can make us hold |
| TLS certificate names and chain kept | 100 names (the count is kept in full), 10 certificates | Keeps the row small |
| Subnets listed by the calculator | 64 (the count is always shown in full; above 2^53 it is written as a power of two) | Keeps the page small |
| Rate limit | 20 runs per minute per user, all tools combined (the subnet calculator included, though it sends nothing) | Abuse protection (`throttle :network` in `Network::BaseController`) |
| History kept | 50 runs per user, project and tool, 90 days | Bounds the table; `NetworkCheck::KEEP_PER_KIND`, `SHANGO_NETWORK_HISTORY_RETENTION_DAYS` |

Planned limits for the second wave (confirmed per tool when it is built):

| Limit | Value |
|-------|-------|
| HTTP check | 10 redirects, 5 s per hop, GET or HEAD only, body discarded |
| DNSBL query | 3 s per list, parallel |
| SPF recursive lookups | 10 (the RFC 7208 limit) |

Values are constants in the services; they are not user settings.

## 6. Security

This feature makes the Shango server open connections to hosts the user names, so it is an SSRF and abuse surface. Rules:

1. **Reuse `Network::SsrfPolicy`** (`app/services/network/ssrf_policy.rb`, shared with the API Client) for port check, TCP ping and TLS certificate. Same behavior and same switch: blocking private, loopback, link-local and cloud-metadata ranges is on by default in production and controlled by `SHANGO_BLOCK_PRIVATE_NETWORKS` (see [`api-client.md`](api-client.md) §6). The policy returns the address that was checked and the probe connects to **that** address (pinning), so DNS rebinding between check and connect is not possible. It was moved out of the `ApiClient` namespace for this feature; do not duplicate it.
2. **DNS checker is not an SSRF vector** because it only sends queries to the fixed public resolvers and to the authoritative nameservers listed in the domain's own `NS` records. Authoritative nameserver IPs go through the same `SsrfPolicy` check, otherwise a domain whose NS record points at `127.0.0.1` or `169.254.169.254` would make Shango send UDP packets inside the network.
2b. **Lookup talks to registries, not to the target.** The only outbound connections are HTTPS requests to the RDAP servers that the IANA bootstrap names (and to `data.iana.org`) and DNS queries to the fixed public resolver for the Team Cymru mapping. Every RDAP hop, redirects included, goes through `SsrfPolicy` and connects to the address that was checked, so a registry cannot be made to point at an internal address; the target host or IP is only ever part of a URL path or a DNS name. Text read from registries and DNS is cut and only strings are kept (`Lookups::Clean`), and entities are read only for the registrar, abuse and organization roles (`Lookups::Entities`), so personal data never reaches the history.
3. **No user-supplied resolvers, no CIDR, one host per run, port cap** (§5), connect-only probes (no payloads, no banners), so the tools cannot be used to exploit services, only to check reachability. The TLS check is the one exception: it sends a fixed STARTTLS dialog and a ClientHello, reads nothing beyond the certificate and the session, and closes.
4. **Rate limit** per user (§5).
5. **Audit log**: every port check, ping, TLS check, email check and lookup, refused ones included, logs one line: `[network] port_check user=<id> project=<id> input="<what was typed>" outcome=<ok or the error> host=<resolved host> ports=<count>` (`port=<n>` for pings, `port=<n> protocol=<tls|smtp|imap|pop3>` for TLS checks, only `host=<domain>` for email checks, `host=<target> type=<domain|ip>` for lookups). The typed input is cut to 100 characters and written with `inspect`, so newlines cannot forge log lines. Secret variables are rejected before anything runs, so no secret value can reach the log.
6. **Project scope**: variables are resolved from the member's current environment of the current project only.
7. **No public exposure**: all endpoints sit behind `authenticate_user!`.

Open decision (see §10): require proof of ownership (DNS TXT or file) before port-checking a public host that is not in the project. Recommended default for v1: not required, because self-hosted installs run from the operator's own IP and the caps, rate limit and audit line limit damage; revisit before any managed cloud offering.

## 7. Error and edge cases

| Case | Behavior |
|------|----------|
| Host fails validation (other scheme, port, spaces, empty) | Form error, nothing is sent |
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
| TLS: nothing listens / no answer in time | Form error `connection_refused` / `connection_timeout` |
| TLS: the port does not speak TLS (plain HTTP on 80, a mail port without STARTTLS) | Form error `handshake_failed` with OpenSSL's reason (`wrong version number`), hinting at STARTTLS |
| TLS: STARTTLS not offered or refused | Form error `starttls_refused` |
| TLS: expired, self-signed, wrong host, missing intermediate, TLS 1.0 | Recorded run with findings; the handshake never fails because of the certificate |
| TLS: host is an IP literal | No SNI is sent; the IP is matched against the IP SANs |
| Email: an IP address instead of a domain | Form error `domain_needed` |
| Email: the domain does not exist (NXDOMAIN) | Form error `domain_not_found` |
| Email: invalid selector, or more than 10 | Form error `invalid_selector` (naming it) / `too_many_selectors` |
| Lookup: the domain is not registered (RDAP 404 for every name tried) | Form error `not_registered` |
| Lookup: no RDAP service for the TLD or the address range (some country-code domains) | Form error `no_rdap_service` |
| Lookup: the registry, the bootstrap or a redirect fails, times out, is not HTTPS or is blocked by the guard | Form error `rdap_unavailable` |
| Lookup: private, loopback, link-local or reserved address | Form error `private_address`; nothing is asked anywhere |
| Lookup: IP address whose RDAP fails but whose ASN is found, or the reverse | Recorded run with the missing part named as a warning (`rdap_failed`, `asn_unavailable`); the run only fails when both are missing |
| Lookup: nobody announces the address | Recorded run with `not_announced` as a warning |
| Email: the resolver times out or fails on one part | Recorded run; that part says `lookup_failed` as a warning instead of calling the record missing |
| Email: no SPF, DMARC or MX record | Recorded run; missing SPF and DMARC are errors, a missing MX a warning |
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
7. `✨ feat(network)` — TLS certificate (first tool of the second wave): `Tls::Handshake`, `Tls::StartTls`, `Tls::Certificate`, `Tls::Trust`, `TlsChecks::Run` and `Findings`, kind `tls` with its codec and digest, the *Security* group of the rail. Specs drive real handshakes against loopback TLS servers with throwaway certificates (`spec/support/tls_certificates.rb`); nothing leaves the machine. Checked by hand against badssl.com (expired, wrong host, self-signed, untrusted root, incomplete chain, TLS 1.0) and STARTTLS on public mail servers.
8. `✨ feat(network)` — Email DNS (second tool of the second wave): `EmailChecks::Run`, `Lookup`, `Spf`, `Dkim`, `Dmarc`, `Mx`, kind `email` with its codec and digest, the `healthy`/`attention`/`broken`/`missing` statuses. Specs stub `Lookup`, so nothing leaves the machine; checked by hand against real domains.
9. `✨ feat(network)` — Lookup (third tool of the second wave): `Lookups::Run`, `Domain`, `Address`, `Asn`, `Entities`, `Clean`, `Rdap::Client` and `Bootstrap`, kind `lookup` with its codec and digest, the `signed`/`unsigned` statuses. Before it, `♻️ refactor` moved `EmailChecks::Lookup` to `Dns::Lookup` for sharing. Specs stub the HTTP layer with WebMock and DNS with `Dns::Lookup`, so nothing leaves the machine; checked by hand against real domains and addresses.

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
