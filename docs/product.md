# Shango — Product Context and Vision

> Product vision, users, scope, and roadmap. For technical design see [`architecture.md`](architecture.md). Nothing described here should be assumed to exist yet; check the real code for current state.

## 1. What is Shango?

**Shango is an open source Developer Workspace that centralizes, connects, and powers with AI the tools a web developer needs throughout the lifecycle of their applications.**

One-liner: *one project-centered workspace where your API client, docs, monitors, servers, logs, and AI share the same context.*

## 2. The problem

Developers use many independent tools for daily work:

| Need | Typical tool |
|------|--------------|
| Test APIs | Postman, Bruno |
| Document APIs | Swagger / OpenAPI |
| Monitor services | Uptime Kuma |
| Manage servers | SSH clients |
| Read logs | Assorted log tools |
| Manage code | GitHub |
| Detect errors | External error-tracking services |
| Investigate problems | Generic AI chat tools |

Consequences:

- **Fragmented information** — the truth about one app is spread across many tools.
- **Duplicated configuration** — the same URL, token, or environment is entered in each tool.
- **Context switching** — solving one incident means hopping between five apps.
- **Context-less AI** — a generic chatbot knows nothing about the failing request, the monitor, or the server.

## 3. The solution and what makes Shango different

Shango is a single workspace where these capabilities are **related and share project context**.

**We are not building a collection of independent tools. We are building tools that work together.**

Differentiators:

1. **Shared context** — an HTTP request can become a documented endpoint *and* a monitor without being configured twice.
2. **Project-first** — everything is organized by project, service, and environment instead of by tool.
3. **Contextual AI** — AI that can see authorized project data (requests, responses, monitors, incidents, logs) and distinguishes evidence from hypotheses.
4. **Self-hostable and open source** — runs locally or on your own infrastructure with no mandatory commercial services.
5. **Framework-agnostic** — works the same for Rails, Node, Laravel, Django, .NET, etc.

## 4. Vision

Shango should become the main place where a developer manages the technical side of their projects. From Shango a developer should be able to:

- Organize projects, services, and environments.
- Create, organize, and run HTTP requests.
- Document APIs.
- Monitor availability and receive incident notifications.
- Connect to servers over SSH from an integrated terminal.
- Inspect errors and logs.
- Investigate problems with contextual AI.
- Integrate repositories, pipelines, and external tools.
- Progressively automate diagnosis and maintenance.

The goal: **reduce the number of tools, configurations, and steps needed to solve problems during software development.**

## 5. Target audience

- **Web developers** using Ruby on Rails, Node.js, Next.js, React, Laravel, Django, .NET, and others.
- **Independent developers** managing several personal projects, clients, APIs, and servers. *(Primary initial persona.)*
- **Small development teams** that need to share documentation, environments, tools, and visibility over their applications.
- **Full-stack and backend developers** who constantly work with APIs, infrastructure, debugging, integrations, and databases.

## 6. Non-goals

- Not an IDE replacement (VS Code, IntelliJ). Shango complements the editor by centralizing tools usually used outside it.
- Not tied to a language or framework.
- Not a SPA, and not a microservices system.
- Not (for now): billing, commercial plans, complex enterprise management, advanced multi-tenant infrastructure, or a plugin marketplace.
- Not a promise to build every tool listed under *Future tools*.

## 7. Product principles

1. **Project-first** — everything revolves around projects.
2. **Integrated by design** — tools share context and reuse existing capabilities.
3. **Developer experience first** — features must be fast, practical, and easy to use.
4. **AI as a capability** — AI empowers the tools; it is not an isolated chatbot.
5. **Open source first** — runnable locally or on the user's own infrastructure.
6. **Progressive complexity** — start simple, evolve as real needs appear.
7. **Security by design** — protect credentials, SSH connections, production data, and sensitive operations.
8. **Extensibility** — adding new tools must not require redesigning the product.

## 8. Core concepts

### Projects

The main entity. A project represents an application, product, or system the developer manages (e.g. an app called *Example*). Each project keeps its own configuration and resources. **Data from one project must never mix accidentally with another's.**

### Teams and roles

A project can have several members. Each member is an **owner** or a **member**. Anyone in the project can see everything in it and send requests; creating collections and environments is open to all, but changing or deleting one is for its creator and the owners. Owners also invite people (by an email link that works once, for the invited address, and expires after a week), promote, remove, hand the project over, and read the team's activity log. A project always keeps at least one owner, and anyone can leave.

### Services

A project may be composed of several services (e.g. Backend API, Frontend Web, Background Workers, Database). A service links tools to a specific component of the system: it can have monitors, servers, endpoints, and events associated. Services are an organizing concept, not a requirement to run microservices.

### Environments

Each project can have environments such as Local, Development, Staging, and Production, each with its own variables and configuration. For example, the base URL of the API differs between Local and Production, and requests refer to it by name instead of hard-coding it.

Sensitive values must be protected. The intent is to avoid configuring URLs, tokens, and credentials repeatedly in different tools.

### Reuse across tools

Shared context is the core of the product. Configure once, use everywhere:

- A **request** can become a **monitor** and an **API documentation** entry.
- An **environment** supplies values to requests, monitors, and servers.
- An **incident** belongs to a project, service, and environment, and can start an **AI investigation**.

### Glossary

| Term | Meaning |
|------|---------|
| Project | Application or system being managed; top-level container |
| Service | Component of a project (API, web, workers, database) |
| Environment | Deployment context (local, dev, staging, production) with its own variables |
| Collection | Organized group of HTTP requests, with nested folders |
| Request | Saved, reusable HTTP call |
| Monitor | Periodic check that evaluates a request against success/failure conditions |
| Incident | Detected failure state of a monitor, from open to recovered |
| Investigation | AI-assisted analysis of an incident or error, based on authorized data |
| BYOK | Bring your own key: user supplies their AI provider credentials |

## 9. Capabilities

### API Client

An HTTP client conceptually similar to Postman or Bruno. Users can create collections, folders and subfolders, organize requests, configure methods, URLs, headers, params, bodies, and authentication, select environments, run requests, inspect responses, and save reusable configurations.

Requests are organized in collections with nested folders, for example *Example → Main API → Authentication → Login*.

The API Client must become a reusable foundation for documentation, testing, and monitoring.

### API Documentation

Generate API documentation from existing requests, using **OpenAPI** as the interoperable format. Users can generate draft docs, add descriptions, document parameters and responses, add examples, define schemas, view interactive docs, and import/export specs. A request does not contain everything needed for a complete contract, so documentation must be enrichable manually.

### Monitoring

Periodic checks of applications and services.

Example: a monitor named *API Health* checks `GET /health` on Production every 5 minutes.

Configurable: name, endpoint, HTTP method, environment, interval, timeout, success and failure conditions, notifications, enabled/paused state. The system records results, detects state changes, identifies incidents, and notifies recoveries.

A monitor can be created **reusing an existing HTTP request**. The user must never configure the same information twice.

### Notifications

Users configure how to receive alerts. Initially: Email and Webhooks. Later: Slack, Discord, and others. Notifications can be tied to projects, monitors, and events. The user controls which events alert them; avoid repetitive, unnecessary notifications.

### Server Management and SSH

Register servers tied to projects and environments, manage SSH connections, and open an interactive terminal from the web UI.

Target flow:

1. Open the project.
2. Select a server.
3. Start an authorized connection.
4. Use the terminal.
5. End the session.

Self-hosted installs connect to servers reachable from the user's infrastructure. A future cloud version would need a way to reach private networks.

### Artificial Intelligence

AI is a cross-cutting capability, not just a generic chat. The assistant understands project context and uses relevant information from available tools. Example questions:

- Why does this endpoint return HTTP 500?
- What does this Rails error mean?
- What could cause this latency?
- Why is my API failing?
- What should I check on my server?
- What do these logs mean?
- What differs between these environments?

Authorized data sources: requests, HTTP responses, monitors, incidents, available logs, server information, documentation, and future repository integrations. Answers must explain their conclusions and **distinguish evidence from hypotheses**.

**Providers:** avoid depending on a single provider. Consider commercial providers, user-configurable models, BYOK, and possibly local models in the future.

**Progressive capability levels:**

1. Explain information provided by the user.
2. Query authorized, read-only tools.
3. Propose actions and solutions.
4. Execute previously authorized actions.

No autonomous dangerous operations. Sensitive actions require permission controls and explicit confirmation.

### Error Detection and Troubleshooting

Help detect, investigate, and resolve problems. Sources: HTTP monitors, failed requests, application logs, exceptions, received events, CI/CD pipelines, external integrations.

**Flagship experience** (one of the main things we want to build):

1. A monitor detects HTTP 500.
2. Shango records an incident.
3. The developer opens the incident.
4. They select "Investigate with AI".
5. The AI queries authorized information.
6. It presents evidence and possible causes.
7. It suggests diagnostic steps.
8. The user decides which actions to run.

### Network Tools

Quick network checks from the project workspace, for the moments when a developer is configuring a server: a **DNS checker** (does a record match what I expect on public resolvers and on the authoritative nameservers, i.e. has it propagated), a **port check** (which ports are reachable from the outside) and a **TCP ping** (is the host online). Targets can use environment variables such as `{{host}}`. Results are shown on screen and not stored. See [`network-tools.md`](network-tools.md). It does not use nmap (license incompatible with AGPL-3.0).

### Future tools

Possible additions over time: API Testing, Webhook Inspector, Mock Servers, API Contract Diff, SSL Certificate Inspector, Database Explorer, Log Explorer, CI/CD Inspector, GitHub Integration, Deployment Inspector, Performance Monitoring, Status Pages, Security Analyzer, JSON Formatter, JWT Decoder, Base64 Encoder/Decoder, UUID Generator, Regex Tester, Timestamp Converter, and other web developer utilities.

This list is **not a commitment**. Each tool must justify its usefulness and its integration with the rest of Shango.

## 10. Key user journeys

1. **Set up a project** — create a project, add services and environments, define variables like `base_url`.
2. **Call an API** — pick an environment, open a request in a collection, run it, inspect the response.
3. **Monitor an endpoint** — turn an existing request into a monitor; get notified on failure and recovery.
4. **Investigate an incident** — open an incident, run "Investigate with AI", review evidence vs. hypotheses, decide next steps.
5. **Fix on a server** — open a server from the project, start an SSH session in the browser, run diagnostic commands.
6. **Publish docs** — generate an OpenAPI draft from a collection, enrich it manually, share or export it.

## 11. Trust and safety

Developers will only trust Shango with production access if:

- Credentials, keys, and tokens are always protected and never exposed unintentionally.
- Connections to servers are explicit and authorized.
- Data from one project never leaks into another.
- AI only sees what the user authorizes, and never performs sensitive actions without explicit confirmation.
- Users keep control of their data (self-hosted by default).

Implementation details are in [`architecture.md`](architecture.md).

## 12. User experience

The interface should be modern, minimalist, fast, professional, consistent, and visually uncluttered, with clear navigation. It must allow:

- Switching easily between projects.
- Reaching project tools quickly.
- Keeping the selected environment as context.
- Navigating between related resources.
- Using interactive tools.
- Reaching the AI assistant from different sections.

Conceptual navigation:

- **Global:** Projects, Settings.
- **Inside a project:** Overview, API Client, Documentation, Monitoring, Servers, Logs, AI Assistant, Settings.

Navigation grows progressively. **Never show nonexistent features as if they were available.**

## 13. Open source and cloud strategy

Shango is initially built for personal use and open source distribution. It must be possible to clone the repo, configure the app, run it locally, install it on one's own server, and manage data without mandatory commercial services.

If the product gets traction, a managed cloud version may follow. Keep that evolution in mind without anticipating complexity we do not yet need.

### License

Shango is licensed under the [GNU Affero General Public License v3.0](../LICENSE) (AGPL-3.0).

- Anyone can run, modify, and self-host Shango freely.
- Anyone offering a modified Shango as a network service must publish their changes under the same license, which protects the option of a managed cloud version.
- Relicensing is possible only for code whose copyright we hold or have been granted the right to relicense. There is no signed CLA: `CONTRIBUTING.md` states that opening a pull request means the contributor accepts the AGPL-3.0 and grants the maintainers a perpetual, irrevocable right to relicense the contribution, keeping their copyright. Contributors are notified of a relicense as a courtesy; their reply is not required. Because the grant is accepted by conduct rather than signature, it is weaker evidence than a signed CLA; revisit this (for example with a CLA bot) if the project grows or a commercial relicense becomes real. Versions already published keep the license they were released under.

## 14. Roadmap

Indicative order; may change as we learn. Each phase must deliver usable, verifiable functionality. Do not build complete systems before they are needed.

| Phase | Name | Scope | Done when… |
|-------|------|-------|------------|
| 1 | Foundation | Authentication, Projects, Services, Environments, basic settings, main layout | A user can sign in, create projects, and manage their services and environments |
| 2 | API Client | Collections, nested folders, requests, HTTP execution, responses | A user can build a collection and run requests against a selected environment |
| 3 | Documentation & Monitoring | OpenAPI, monitors, scheduler, incidents, notifications | A request can become a monitor; failures create incidents and send notifications; docs export as OpenAPI |
| 4 | AI Assistant | Configurable providers, contextual chat, error analysis, authorized query tools | A user can investigate an incident with AI using their own provider key |
| 5 | Server Management | Servers, SSH, integrated terminal, assisted diagnosis | A user can open a protected SSH session from a project |
| 6 | Developer Operations | Logs, webhooks, GitHub, CI/CD, additional tools | Logs and external events feed incidents and investigations |

Network Tools (§9) belongs to no phase on purpose: it depends only on Foundation and Environments, so it can ship whenever it is prioritized. Proposed, pending product owner confirmation.

## 15. Open product questions

Decisions not yet made; ask before assuming:

- Whether finer roles are needed (an admin, a read-only viewer) and whether collections or environments should be shared with specific members instead of the whole project.
- How logs get into Shango (which sources matter first).
- Which notification channels come after email and webhooks.
- Which of the *Future tools* earn a place after the core phases.

## 16. Working agreements for product decisions

When scoping or implementing a feature:

1. Understand how it contributes to the product goal and which roadmap phase it belongs to.
2. Identify how it relates to projects and existing tools.
3. Prefer reusing existing capabilities over adding configuration.
4. Prioritize a simple developer experience.
5. Do not add features beyond the requested scope.
6. Ask before decisions that significantly change the product.

Always distinguish between **product vision**, **roadmap**, and **actual repository state** (the code). Technical decisions live in [`architecture.md`](architecture.md).
