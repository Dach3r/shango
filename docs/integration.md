# Shango — Integration between modules

> How the modules of a project (API Client, Monitoring, Network Tools) are tied together, so a developer moves between them without re-entering anything. Product reasoning: [`product.md`](product.md) §3 and §7. Check the code for the real state.

## 1. Principle

Configure once, use everywhere. Every module reads the same project, the same selected environment and the same saved records; a screen that shows something another module can act on links to it, prefilled.

## 2. Cross-links

| From | To | How |
|------|----|-----|
| Saved request | Monitor | *Monitor this request* in the request menu opens `new_monitoring_monitor_path(kind: "http", api_request_id:)` in request mode ([`monitoring.md`](monitoring.md) §12 step 12) |
| Request monitor | Request | *Open request* on the monitor page |
| Network run (ping, ports, TLS, DNS, lookup) | Monitor | *Monitor this* (`NetworkHelper#network_monitor_path`) opens a TCP, SSL or domain monitor with `target` and `port_number` |
| TCP, SSL or domain monitor | Network tool | *Check in Network* (`MonitoringHelper#monitor_network_path`) opens ping, TLS or lookup prefilled |

`host` and `port` are reserved URL options of the route helpers, so the parameters are `target` and `port_number`.

## 3. Overview

`/overview` (`Projects::OverviewsController`, `Projects::Overviews::Build`) is the project's front page and the place the root redirects to. It reads, without a table of its own: the monitor counts by status, the open incidents, the non-team `AuditEvent`s (`AuditEvent.workspace`, newest 8), the member's own latest requests and network checks (both are private to them) and counts of requests, monitors and environments. A project with nothing in it shows the first steps instead.

## 4. Environment scope

The environment a member selects in the status bar narrows what monitors and incidents list: `UptimeMonitor.in_environment(environment)` keeps that environment's monitors plus those that belong to none (push monitors, for instance). `EnvironmentScope` (`scope_environment`) reads it from the member and `?environment=all` widens it; `projects/_environment_scope` always says which one is on and links to the other. The Overview, the monitor list and the incident list use it; the counts in the Monitoring sidebar stay project-wide, so they match the monitor limit.

## 5. Incidents

`/monitoring/incidents` (`Monitoring::IncidentsController`) lists every incident of the project, newest first, 25 per page, filtered by `?state=open|resolved` and narrowed by the environment scope. Open incidents are flagged everywhere: a red count in the status bar (`StatusBar::Component`, linking to the open ones), on *Monitoring* in `ToolsNav` and in the Monitoring sidebar. The count comes from `ProjectContext#open_incident_count`, one indexed query per page.
