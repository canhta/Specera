# S4 — dashboard, analysis, observability

Liveness via authenticated `gh api repos/<r>` and `registry.npmjs.org/<p>/latest`,
**2026-08-04**. `FACT` = command output / file path / URL. Licences read from the repo where
load-bearing.

`INFERENCE` **Framing.** MCP is the primary surface (S3). Every graph view Specera needs is
a **bounded subgraph** — one chain, one blast radius, one neighbourhood; "render the whole
graph" is a demo. That kills the WebGL-vs-canvas argument up front and lets maintenance
velocity decide. The dashboard must also add **zero new runtime** to the deploy.

---

## 1. Framework — **Vite + React SPA, served as static assets by S3's API**

| Candidate | Licence | Stars | Pushed | Archived | Verdict |
|---|---|---|---|---|---|
| **vitejs/vite** | MIT | 82,185 | 2026-08-04 | false | **PICK** (build tool) |
| vercel/next.js | MIT | 141,328 | 2026-08-04 | false | Runner-up |
| remix-run/react-router | MIT | 56,537 | 2026-08-03 | false | Viable, no edge |
| TanStack/router | MIT | 14,887 | 2026-08-03 | false | Too new for a 5-year install |
| sveltejs/kit | MIT | 20,717 | 2026-08-04 | false | Fine; smaller hiring pool |
| withastro/astro | **MIT** — API says `NOASSERTION`; `LICENSE` reads `MIT License / (c) 2021 Fred K. Schott` | 61,511 | 2026-08-03 | false | Wrong shape (content sites) |

Support: `@tanstack/react-query` MIT 50,054★ 2026-08-03 · `@tanstack/react-table` MIT
28,265★ 2026-08-04 · `radix-ui/primitives` MIT 19,125★ 2026-07-31 (WAI-ARIA primitives =
a11y floor) · theming via a `data-theme` attribute + `prefers-color-scheme`, no dependency.

**Why SPA over Next.js**
1. `INFERENCE` It is the **only choice that does not constrain S3's runtime pick**. Next.js
   forces a Node process into the deploy even if S3 picks Rust or Go; a `dist/` folder is
   served by anything, including an embedded-assets single binary.
2. `FACT` Next.js has two build-time network calls an air-gapped build must be told about:
   telemetry (`packages/next/src/telemetry/storage.ts` — opt-**out**, default enabled) and
   `next/font/google` (`packages/font/src/google/fetch-css-from-google-fonts.ts` fetches
   Google Fonts during `next build`). Both avoidable; neither exists with a SPA.
3. `INFERENCE` Smaller security review — no server-side React, no RSC payload
   deserialisation, no `next start`.

**Next.js is a real runner-up, not a strawman.** `FACT` sourcebot is a working enterprise
self-host on it: `packages/web/next.config.mjs:6` → `output: "standalone"`;
`Dockerfile:87,151` → `NEXT_TELEMETRY_DISABLED=1` at build *and* runtime;
`docker-compose.yml` = app + Postgres + Redis; Helm lives in a separate repo
(`sourcebot-dev/sourcebot-helm-chart`, MIT, **8 stars**, pushed 2026-07-31 — `INFERENCE`
so ship Compose in v1, Helm in v2). `FACT` sourcebot is FSL-1.1-ALv2 with a separately
licensed `ee/` folder (`LICENSE.md`) — read for shape only, **no code reused**.

**Changes my mind:** if the dashboard grows an authoring surface (AC → Scenario editing —
the proposal's open question), server-rendered forms start paying for themselves; switch
to Next.js standalone, which sourcebot proves works.

**Proxy** — `FACT` adopt sourcebot's answer verbatim: `NODE_USE_ENV_PROXY=1` +
`HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY`
(`docs/docs/configuration/environment-variables.mdx:46-49`), plus `NODE_EXTRA_CA_CERTS`
for TLS-inspecting proxies. **SSO** is S3's problem, not the SPA's: the SPA holds a session
cookie and never sees an IdP. `FACT` Flag to S2/S3 — `gh api repos/boxyhq/jackson`
**redirects to `ory/polis`**, Apache-2.0 (LICENSE confirms), 2,257★, pushed 2026-07-27,
not archived. The brief's BoxyHQ Jackson has been renamed/absorbed.

---

## 2. Graph viz — **Cytoscape.js**, hard cap **2,000 nodes / 5,000 edges per view**

| Library | Licence | Stars | Pushed | Archived | Human commits since 2026-02 | Verdict |
|---|---|---|---|---|---|---|
| **cytoscape/cytoscape.js** | MIT | 11,131 | 2026-07-30 | false | 63 (maxkfranz) + 4 others | **PICK** — 21 open issues, v3.34.0 (2026-06-02) |
| jacomyal/sigma.js | MIT | 12,121 | 2026-07-08 | false | **6 total**, 2 core devs | Runner-up (WebGL) |
| visjs/vis-network | `(Apache-2.0 OR MIT)` (npm) | 3,608 | 2026-08-03 | false | 22, **20 by one person** | Reject — bus factor 1 |
| xyflow/xyflow (React Flow) | MIT (`LICENSE`, webkid GmbH) | 37,901 | 2026-08-03 | false | active | Reject — see below |
| antvis/G6 | MIT | 12,215 | 2026-07-15 | false | 16 | Reject — support in CN-language issues |
| d3/d3-force | ISC | 1,993 | **2023-12-30** | false | 0 | Layout primitive, not a viewer |
| vasturiano/react-force-graph | MIT | 3,255 | 2026-02-04 | false | — | Reject — one maintainer, 6mo stale |
| mermaid-js/mermaid | MIT | 89,558 | 2026-08-03 | false | active | **Keep, scoped** — static diagrams ≤ ~150 nodes |
| graphology/graphology | MIT | 1,715 | 2026-07-21 | false | **1 since 2026-01** | Only if sigma wins |

**React Flow licence, checked carefully.** `FACT` The library is MIT (`LICENSE`,
`Copyright (c) 2019-2025 webkid GmbH`); "React Flow Pro" is a *sponsorship/support*
subscription, not a licence tier — but `README.md:27-29` applies commercial pressure
("using React Flow at your organization and making money from it? …We rely on your
support") and Pro examples are not MIT. `INFERENCE` Legally clean, commercially noisy; the
real disqualifier is technical — one DOM node per graph node dies past ~1–2k.

**Node-ceiling evidence**
- `FACT` `.spike/clones/codegraphcontext/website/src/components/CodeGraphViewer.tsx:752` —
  a shipped code-graph viewer defines `const isMassive = filteredData.nodes.length > 3000;`
  and above it stops drawing real nodes, stamping bare `fillRect` squares. Its own author
  treats 3k as the degradation point.
- `FACT` `.spike/clones/graphify/worked/rsl-siege-manager/graph.html` (1.85 MB, the artifact
  named in the brief) uses **vis-network loaded from
  `https://unpkg.com/vis-network/standalone/umd/vis-network.min.js`** — a CDN `<script>`,
  which **breaks air-gap outright**. ~1,886 nodes / ~3,876 edge refs; forceAtlas2 with
  `stabilization:{iterations:200}` and `physics:{enabled:false}` set on
  `stabilizationIterationsDone` — even at 1.9k they must kill physics to stay usable.
  It does **not** use Mermaid.
- `FACT` sigma.js README:14 — "visualizing graphs of **thousands** of nodes and edges using
  WebGL". Genuinely faster than canvas above ~10k.
- `INFERENCE` Convergent clone evidence, read sceptically: `codegraphcontext` and `GitNexus`
  both declare `sigma` + `graphology` + `graphology-layout-forceatlas2`; `deepwiki-open`
  and `gitdiagram` use Mermaid; `codegraph` uses `chart.js`. But codegraphcontext's sigma
  deps are **dead** — its actual viewers `import ForceGraph2D from "react-force-graph-2d"`.

**Stated ceiling.** Server enforces **2,000 nodes / 5,000 edges** per graph response; beyond
that the API refuses and returns the table view + "narrow your query". `INFERENCE` Compute
layout **server-side** and ship coordinates, so the browser never runs a force simulation.
Above the cap the answer is a different query, not a different renderer. A partner genuinely
needing 20k interactive nodes is the one condition that flips this to sigma.js and forces us
to accept its bus factor.

**Why Cytoscape over sigma:** maintenance velocity (63 vs 6 human commits since 2026-02);
21 open issues on 11k stars; built-in BFS/DFS/shortest-path/centrality that chains and
blast-radius need — sigma delegates these to graphology, which has **1 commit since
January**; and **compound nodes**, mapping directly onto `Feature contains Scenario`.

**Accessibility.** `INFERENCE` A force-directed canvas is not accessible, full stop. Every
graph view ships a **keyboard-navigable table of the same subgraph as a first-class peer**
(a tab, not a hidden fallback) — nodes, edges, provenance. It is also the export format and
what an auditor screenshots. Cytoscape gets `role="img"` + an `aria-label` with node/edge
counts; nothing more is claimed.

---

## 3. Minimum credible view set — six

`FACT` Shape reference (`.spike/evidence-greptile.md`): Greptile's dashboard is PRs
reviewed, merge times, addressed rates, critical bugs caught, filter + export. Note what
that list *is* — five numbers, one filter, one export. Match that discipline.

| # | View | Answers | Renderer |
|---|---|---|---|
| 1 | **Coverage** | ACs with 0 / ≥1 scenario / ≥1 passing run, by team + epic + service | Table + 3 stat tiles |
| 2 | **Gaps** | Orphaned scenarios (no AC), scenarios with no test binding, tests with no run in N days | Table |
| 3 | **Artifact** | One node: provenance, neighbours, chain up to merge commit and down to run | **Graph** (only place it appears) + table peer |
| 4 | **Impact** | Given a PR/commit/branch: which ACs, scenarios, services are in the blast radius | Bounded subgraph + table |
| 5 | **Freshness** | Artifacts past their potpie-ontology TTL, sorted by staleness | Table |
| 6 | **Policy** | Per governance rule: pass/fail + offending nodes | Table + stat tile |

`INFERENCE` View 6 is not optional — the proposal's §6 says governance is the product, and
a policy with no view is a policy nobody trusts.

**On every view, non-negotiable:** provenance filter (`EXTRACTED`/`INFERRED`/`AMBIGUOUS`)
**defaulting to high-confidence and always visible**, so nobody mistakes an inference for a
fact; CSV + JSON export; permalink encoding full filter state. **Trend over time** = one
sparkline per headline number from a nightly snapshot table. Not a TSDB, not a metrics
stack, not a date-range picker.

**Would NOT build in v1:** dashboard builder / drag-drop widgets; saved, scheduled or
emailed reports; per-user dashboards; visual query builder (MCP + one raw-query box
suffices); 3D graph; WebSocket live updates; in-app alerting engine; PDF export; admin
usage-analytics page; node comment threads; i18n beyond English; mobile-optimised layouts
(responsive-degrade only); **graph editing — v1 is read-only.**

---

## 4. Charting — **Recharts ^3**

| Library | Licence | Stars | Pushed | Archived | Verdict |
|---|---|---|---|---|---|
| **recharts/recharts** | MIT (npm `3.10.1` MIT) | 27,461 | 2026-08-03 | false | **PICK** |
| observablehq/plot | ISC | 5,341 | 2026-07-13 | false | Runner-up |
| apache/echarts | Apache-2.0 | 66,972 | 2026-08-04 | false | Fine, ~1 MB, imperative |
| airbnb/visx | MIT | 20,992 | 2026-06-22 | false | Fine, more assembly |
| chartjs/Chart.js | MIT | 67,620 | 2026-05-27 | false | No React story |
| plotly/plotly.js | MIT | 18,277 | 2026-08-03 | false | ~3 MB, scientific shape |
| frappe/charts | MIT | 15,087 | **2025-07-02** | false | 13 months stale |
| **highcharts/highcharts** | **`NOASSERTION`** | 12,472 | 2026-08-04 | false | **REJECT — commercial/dual** |
| **ag-grid/ag-charts** | **`NOASSERTION`** | 478 | 2026-08-03 | false | **REJECT — commercial/dual** |
| **amcharts/amcharts5** | **`NOASSERTION`** | 440 | 2026-08-03 | false | **REJECT — commercial/dual** |

`FACT` The three `NOASSERTION` rows are the trap the brief flags — GitHub reports no SPDX id
because the terms are proprietary or free-for-noncommercial with a paid commercial tier.
None can ship in an open-source, self-hosted product. Read the LICENSE; never trust a
shields.io badge.

**Why Recharts.** `FACT` Corroborated by two clones independently —
`sourcebot/packages/web/package.json` pins `recharts ^2.15.3`,
`codegraphcontext/website/package.json` pins `^2.15.4`. `FACT` It ships a first-class
`accessibilityLayer` (keyboard + screen reader), present in `src/chart/CartesianChart.tsx`
and `src/chart/PolarChart.tsx` — procurement evidence, not a nice-to-have. Pin `^3`: v3 is
a breaking migration off the 2.x both clones use; take it once, now. `INFERENCE` **Honest
alternative:** v1 needs four shapes (sparkline, bar, stacked bar, donut) ≈ 150 lines of
hand-rolled SVG, zero dependency. Recharts wins only because trend/breakdown charts accrete
and hand-rolled ones won't survive that.

---

## 5. Observability — OpenTelemetry, **default-off, no Specera endpoint exists**

`FACT` npm versions, 2026-08-04, **all Apache-2.0**. **Stable:** `@opentelemetry/api`
**1.9.1** (1.x — the only thing library code should import), `sdk-trace-node` **2.10.0**,
`sdk-metrics` **2.10.0**. **Still 0.x:** `sdk-logs` 0.221.0, `sdk-node` 0.221.0,
`exporter-trace-otlp-http` 0.221.0, `auto-instrumentations-node` 0.79.0,
`instrumentation-pg` 0.73.0.

Repos: `opentelemetry-js` Apache-2.0 3,427★ 2026-08-03 · `opentelemetry-collector`
Apache-2.0 7,341★ 2026-08-04 · `pinojs/pino` MIT 18,106★ 2026-08-01 ·
`prometheus/prometheus` Apache-2.0 65,528★ 2026-08-03 — none archived.

`INFERENCE` **The caveat nobody states:** the OTel JS *API* and trace/metric *SDKs* are
stable, but **everything needed to actually export — every OTLP exporter, `sdk-node`, and
every instrumentation — is still 0.x** and can break on a minor bump. So: pin 0.x OTel
packages with `=`, never `^`, and gate telemetry init behind one flag, so a bad bump
degrades to "no telemetry", never "no boot".

- **Logs** — pino, structured JSON to stdout, trace-id injected. **Do not** route logs
  through `sdk-logs` (0.x) in v1; the customer's collector scrapes stdout.
- **Metrics** — `/metrics` in **Prometheus text format** by default (zero customer config;
  every enterprise has a scraper), OTLP push optional. `FACT` sourcebot's shape:
  `grafana.alloy` scrapes `localhost:6070` and `:3060` at `/metrics` every 15s.
- **Traces** — `api` + `sdk-trace-node` (or the stable equivalent if S3 picks Rust/Go),
  W3C `traceparent`. **Instrument MCP tool calls first** — the primary surface, and the one
  that generates "why is it slow" tickets.

**Default-off, plainly.** Specera emits telemetry **iff** the operator sets
`OTEL_EXPORTER_OTLP_ENDPOINT` (or scrapes `/metrics`). **No Specera-owned endpoint is
compiled into any artifact.** No install ping, no version beacon, no `@scarf/scarf`, no
PostHog, no default Sentry DSN; `NEXT_TELEMETRY_DISABLED=1` in any stage touching Node
tooling. CI-testable: **an egress-blocked container must complete install, index and a
query with zero outbound connections** — that test *is* the claim.

`FACT` What we refuse to copy: sourcebot ships a **hardcoded PostHog key as a zod default**
(`packages/shared/src/env.server.ts:246`,
`POSTHOG_PAPIK: z.string().default("phc_lLPuFFi5LH6c94eFJcqvYVFwiJffVcV6HD8U4a1OnRW")`),
`SOURCEBOT_TELEMETRY_DISABLED: booleanSchema.default('false')` (line 431), and
`entrypoint.sh:94,154` defaults it false then `curl`s PostHog an `install` event on first
run — opt-**out** phone-home. GitNexus's `@scarf/scarf` (`scarf-sh/scarf-js`, Apache-2.0,
177★, 2026-07-03, not archived) is the same class of thing beside its no-phone-home page.

**What default-off costs us — out loud.** **Zero product analytics**: no install count, no
activation funnel, no feature-usage data, no crash aggregation, no "which queries do people
actually run". Roadmap calls come from design partners, issues and docs traffic instead.
Permanent and real, and I would pay it, because "no phone-home" is a differentiator only if
it is literally true in the source. Honest mitigations: opt-**in** `specera telemetry
enable` that prints the exact JSON before sending; `specera diagnostics bundle` producing a
file the user reads and attaches to an issue (zero automatic egress); registry pull counts.

---

## 6. Grafana — **webhook in + read API for backfill; no plugin in v1**

`FACT` `grafana/grafana` is **AGPL-3.0** (76,044★, 2026-08-04) — but nothing a plugin links
against is: `grafana-plugin-sdk-go` **Apache-2.0** (254★, 2026-08-03), `plugin-tools`
Apache-2.0 (87★, 2026-08-03), npm `@grafana/data` 13.1.1 / `@grafana/ui` 13.1.1 /
`@grafana/create-plugin` 7.9.1 all Apache-2.0. `FACT` grafana.com/legal/plugins permits
catalog plugins under Apache-2.0/MIT/BSD, and Grafana's CEO (2021 relicensing Q&A) states
"Plugins, agents, and certain libraries will remain Apache-licensed." `UNVERIFIED` Grafana
has **never explicitly stated** that an out-of-process backend plugin is not an AGPL
derivative work — implied, not asserted. Needs counsel; not a legal opinion.

**Decision: both directions, webhook first.**
1. **Ingest (primary)** — `POST /api/v1/ingest/grafana` receiving Grafana alerting
   **webhook contact points**. `FACT` Payload carries `status` (firing/resolved) and
   `alerts[]` with `labels`, `annotations`, `startsAt`, `endsAt`, `generatorURL`, and
   `fingerprint` (stable per label set — **the incident idempotency key**); supports HMAC
   signing, custom headers and fully templated payloads, so we publish *our* schema rather
   than parsing theirs. Push suits `release → incident`: a firing alert is an event, it
   needs no credentials into the customer's Grafana, and it works with no outbound route.
2. **Read API (backfill only)** — history cannot be reconstructed from webhooks you weren't
   listening for. `FACT` `GET /api/v1/provisioning/alert-rules` and
   `/api/prometheus/grafana/api/v1/rules` (rules); `/api/v1/rules/history` and
   `/api/alertmanager/grafana/api/v2/alerts` (instances/state); **`GET /api/annotations`**
   with `from`/`to`/`tags` — the **deploy/release marker** source, i.e. the actual left-hand
   side of `release → incident`. Auth via **service accounts + bearer tokens** (`FACT` API
   keys are deprecated). `FACT` Grafana 13 is deprecating `/api` for `/apis` — abstract the
   base path from day one.
3. `FACT` **Do not build on Grafana OnCall.** `gh api repos/grafana/oncall` redirects to
   `grafana-cold-storage/oncall`: **archived=true**, last push 2026-03-24, AGPL-3.0,
   maintenance mode since 2025-03-11. Successor Grafana Cloud IRM is **cloud-only**, which
   air-gapped customers cannot use. The Kuzu failure mode — one API call.

**Ship a datasource plugin? Honestly: eventually, not v1.**
- The leverage is real *only for metrics-shaped questions*. A Grafana panel is good at
  "coverage % over time by team" and could delete our trend charts; it is useless for "show
  me this traceability chain". A plugin can replace views 1, 5 and the sparklines —
  **never views 3 and 4**.
- `FACT` Cost is lower than feared: no Grafana approval to *write* a plugin, private signing
  is free, and an unsigned private plugin loads in self-hosted Grafana via
  `GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=<id>` (`conf/defaults.ini:2194`,
  `allow_loading_unsigned_plugins`). Catalog publishing needs manual review with **no
  published SLA** (~1–2 weeks is community anecdote, `UNVERIFIED`).
- **But the cheap path exists.** `FACT` `grafana/grafana-infinity-datasource` —
  **Apache-2.0**, 1,066★, 2026-08-03, not archived, **maintained by Grafana Labs** — queries
  arbitrary JSON/CSV/XML/GraphQL HTTP endpoints with bearer/OAuth2 auth. `INFERENCE` A
  documented, stable, read-only JSON query endpoint gives teams ~80% of the plugin's value
  for **zero plugin engineering, zero signing, zero review**. `FACT` Design for one caveat:
  Infinity's alerting/caching/recorded-queries work only with the **backend parser** — so
  emit flat arrays of objects, no client-only nesting.
- **Verdict:** v1 ships the JSON endpoint plus a reference Infinity dashboard JSON. Build a
  first-party plugin only once design partners have wired Infinity up and hit a named limit.
  That is the falsifiable trigger.

---

## Top recommendation per area

| Area | Pick | Runner-up |
|---|---|---|
| Framework | **Vite + React SPA** served by S3's API (MIT) | Next.js `output: standalone` (MIT) |
| Graph viz | **Cytoscape.js** (MIT), server-side layout, cap 2k nodes / 5k edges | sigma.js + graphology (MIT) |
| Views | **Six**: coverage, gaps, artifact, impact, freshness, policy | — |
| Charts | **Recharts ^3** (MIT) | Observable Plot (ISC), or hand-rolled SVG |
| Observability | **OTel api 1.9.1 + sdk-trace-node/sdk-metrics 2.10.0**, pino, `/metrics`, **default-off** | — |
| Grafana | **Alert webhook in + annotations/rules API backfill**; JSON endpoint for **Infinity** (Apache-2.0) | First-party datasource plugin, v2 |

**Biggest risk.** The 2,000-node cap is a **product bet, not a rendering limit** — it
assumes every question a user brings resolves to a bounded subgraph. If a design partner's
first ask is "show me the whole traceability graph for the release", the cap reads as a
defect, the table peer reads as a consolation prize, and we retrofit WebGL — depending on
sigma.js, whose 6 human commits since 2026-02 and 2-person core are exactly the bus factor
this brief tells us to avoid. Mitigation: make the cap a config value and instrument how
often queries hit it, on the *customer's* telemetry, from week one.

**Could not verify.** (1) Whether an out-of-process Grafana backend plugin creates an AGPL
obligation — Grafana implies not, never states it. (2) Grafana catalog review turnaround —
no published SLA. (3) Whether Infinity supports POST bodies and custom headers, which our
query endpoint may need. (4) **Cytoscape.js's real frame rate at 2k nodes on
enterprise-standard hardware** — the 3,000 figure is codegraphcontext's judgement about a
*different* renderer, not a measurement of ours. **Experiment, half a day:** generate
synthetic 500 / 2k / 5k / 10k-node Gherkin graphs, render in Cytoscape with precomputed
layout, measure time-to-interactive and pan/zoom FPS in Chrome and Firefox on 4-core/8 GB.
That number sets the cap, not this document.
