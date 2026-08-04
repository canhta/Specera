# Build roadmap — Specera

Tracking document. Research is in [`spike/`](spike/) and is closed; this is the
build plan. Every task carries enough context to be picked up cold.

**Architecture rule:** the platform is complete at M0. Connectors are data sources
that plug in afterwards. *If adding a connector requires changing core, the
architecture is wrong.* Anything touching the data model or the trust boundary
belongs in M0 — retrofitting tenancy, audit, or provenance is brutal; adding a
connector is routine.

Stack decisions: [`spike/stack.md`](spike/stack.md). Product: [`spike/product-proposal.md`](spike/product-proposal.md).

Status legend: `todo` · `wip` · `done` · `blocked`

---

## M0 — platform skeleton

Ships with exactly **one** connector (M1) to prove the SDK is not theoretical.
One connector proves the contract; two or more means building connectors instead
of a platform.

| ID | Task | Status |
|---|---|---|
| M0-00 | Repo scaffolding | todo |
| M0-01 | Ontology + schema | todo |
| M0-02 | Graph store | todo |
| M0-03 | Connector SDK | todo |
| M0-04 | Ingestion pipeline | todo |
| M0-05 | Query layer | todo |
| M0-06 | MCP server | todo |
| M0-07 | REST + OpenAPI | todo |
| M0-08 | Dashboard shell | todo |
| M0-09 | Auth + RBAC + tenancy | todo |
| M0-10 | Audit log | todo |
| M0-11 | Deploy | todo |
| M0-12 | Observability | todo |

### M0-00 · Repo scaffolding
**Context** — pnpm workspaces only; `FACT` 0/19 competitor repos use Nx/Turborepo/Bazel, and Nx carries a critical CVE. TypeScript on Node 24 LTS.
**Done when** — `packages/{core,connector-sdk,connectors,mcp,api,cli,dashboard}` exist; vitest + Biome + `tsc` project refs + Changesets run in CI; `NOTICE` file exists (Apache-2.0 deps require attribution from commit one).
**Evidence** — [`spike/stack.md`](spike/stack.md) §1, §5

### M0-01 · Ontology + schema
**Context** — port potpie's `context-core` ontology to TS. **Only `context-core`** — potpie's engine depends on SSPL FalkorDB. Take its per-type `freshness_ttl_hours` / `source_of_truth` (`ontology.py:160-165`), `EVIDENCE_STRENGTHS` (`:92`), and the `invalid_at` supersession rule (`:200-207`).
**Depends** M0-00
**Done when** — entity + predicate types defined; every edge carries `provenance ∈ {EXTRACTED, INFERRED, AMBIGUOUS}`, `confidence`, and bitemporal validity; artifacts keyed by `(work item key, merge commit)`.
**Why merge commit** — `FACT` head SHAs survive only 19.8% of merges (25.0% in a mature corpus, median repo 0%); merge commits resolve at 99.5%.
**Evidence** — [`spike/decision.md`](spike/decision.md) §7, [`spike/sdlc-model.md`](spike/sdlc-model.md) §4

### M0-02 · Graph store
**Context** — no graph database. Every embedded one failed the gate: Kuzu archived, Cozo dormant, Cayley dead, SurrealDB/Memgraph BSL, FalkorDB SSPL, Neo4j GPL-3.0. Relational instead: `node:sqlite` in the CLI, Postgres on the server, recursive CTEs.
**Depends** M0-01
**Done when** — base table is `edges_raw`; the **view named `edges` is confidence-filtered**, so the naive query is safe by default; `_raw` access is `REVOKE`d in Postgres and CI-linted in SQLite; forward-only expand/contract migrations; `input_digest = blake3(extractor_version ‖ content_hash)` **excluding** schema version.
**Why the view** — `FACT` codegraph computes confidence then discards it before insert; codegraphcontext and stakgraph store it and never read it. Forgetting to filter must be impossible, not merely discouraged.
**Verified** — the pattern runs on Node v24.18.0 with zero dependencies; a 5-hop traversal excluded a 0.22-confidence edge automatically.
**Evidence** — [`spike/stack.md`](spike/stack.md) §2, §3

### M0-03 · Connector SDK
**Context** — this is what makes it a platform. Connectors depend on `@specera/connector-sdk` **only**, never on `core`; the SDK publishes independently so out-of-tree connectors are the same artifact as in-tree ones.
**Depends** M0-01
**Done when** — a connector can be written, built, and loaded without importing or modifying `core`.
**Evidence** — [`spike/stack.md`](spike/stack.md) §5

### M0-04 · Ingestion pipeline
**Context** — a static typed DAG, **not** a plugin surface; `FACT` `GitNexus/ARCHITECTURE.md:119` deliberately chose "no plugins" here. Must be idempotent: key on `(source, delivery_id, sha256(body))` — `FACT` `X-GitHub-Delivery` is stable across redeliveries, so it dedupes but is useless as a replay nonce; the same id with different bytes is an alarm, not an update.
**Depends** M0-02, M0-03
**Done when** — re-ingesting the same input is a no-op; a changed body under a seen id raises.

### M0-05 · Query layer
**Context** — traversal for `AC → scenario → test → run → commit → release → incident`. Provenance appears in every result.
**Depends** M0-02
**Done when** — variable-depth traversal via recursive CTE; results carry provenance and an `omitted` count so silent filtering is impossible.

### M0-06 · MCP server
**Context** — the primary surface; agents first, humans second. `@modelcontextprotocol/sdk` (TS), stdio + Streamable HTTP, no SSE. **9 tools, hard cap 12**: `search, get, neighbors, trace, coverage, impact, policy_check, provenance, stats`.
**Depends** M0-05
**Done when** — provenance is `required` in every `outputSchema`; `EXTRACTED`-only by default; **zero side-effecting tools**; content from ingested repos, tickets, and PR bodies is treated as untrusted data and never returned as instructions.
**Why zero writes** — `FACT` GitNexus needs a whole `read-only-policy.ts` with an env flag only because its default surface contains writes.
**Evidence** — [`spike/security.md`](spike/security.md), [`.spike/findings-supply-chain.md`](../.spike/findings-supply-chain.md)

### M0-07 · REST + OpenAPI
**Context** — Fastify, OpenAPI 3.1, Zod-derived. tRPC rejected (not language-agnostic); GraphQL rejected (query-planner exposure, useless audit granularity).
**Depends** M0-05
**Done when** — schema published; serves the dashboard as static assets.

### M0-08 · Dashboard shell
**Context** — Vite + React SPA served by the API, so no extra runtime enters the deployment. Six views, no more: coverage, gaps, artifact, impact, freshness, policy. Cytoscape.js, **hard cap 2,000 nodes / 5,000 edges**, server-side layout.
**Depends** M0-07
**Done when** — views render; no CDN fetches at runtime. `FACT` graphify's `graph.html` loads vis-network from unpkg and breaks air-gap outright — do not repeat.
**Not in v1** — dashboard builder, scheduled reports, query builder, 3D, live updates, PDF export.

### M0-09 · Auth + RBAC + tenancy
**Context** — the most expensive retrofit in the whole plan, so it lands in M0. App is an **OIDC relying party only**; SAML/SCIM arrive later via a bridge container, so swapping the provider is a container change rather than a code migration.
**Depends** M0-00
**Done when** — `org_id` + row-level security exist **in the first migration**; roles defined with `ADMIN` and `APPROVER` deliberately disjoint; granularity `org → project → repo`, graph nodes inheriting their repo. Multi-tenant schema, single-tenant deployment.

### M0-10 · Audit log
**Context** — append-only enforced by the database (`REVOKE UPDATE, DELETE`) plus a per-org hash chain. **No pruner, ever** — `FACT` sourcebot's `auditLogPruner.ts` bulk-deletes audit rows on a timer, which is Xray's mutable-history failure with a scheduler attached. The bar is Vera: approved records read-only, delete-denied.
**Depends** M0-09
**Done when** — deletion is impossible at the DB grant level; the chain verifies.
**Deferred to M0.1** — customer-KMS Merkle checkpoints. Public transparency logs are **rejected**: `FACT` a Fulcio cert embeds the CI OIDC subject containing the repository path, so a public log leaks private repo names and build cadence. Pick two of publicly-verifiable / non-repudiable / confidential — we pick **non-repudiable + confidential**.
**Evidence** — [`spike/security.md`](spike/security.md) §2.5

### M0-11 · Deploy
**Context** — digest-pinned Dockerfile + Compose + air-gap tarball. No unpinned `npx -y ...@latest` anywhere. Helm at M0.1 — `FACT` 0/19 clones ship a `Chart.yaml`, so it is the category's universal deferral, but it gates the large-install tier.
**Depends** M0-07
**Done when** — installs offline from the tarball; no image tag is `:latest`.

### M0-12 · Observability
**Context** — OpenTelemetry + pino, exporting to the **customer's** collector. **Default-off.** `FACT` sourcebot ships a hardcoded PostHog key as a zod default with telemetry defaulting to enabled and an install ping — this cannot coexist with a no-egress claim, and no-egress is the trust differentiator.
**Depends** M0-00
**Done when** — a fresh install makes zero outbound connections; enabling telemetry is opt-in with a printable allowlist.

---

## M1+ — connectors

Ordered by how reliably the source data exists, highest first. None of these may
change core.

| ID | Connector | Substrate exists | Status |
|---|---|---|---|
| M1 | **code** — graphify behind `CodeGraphProvider` | **100%** — code always exists | todo |
| M2 | **git** — `PR → merge commit → release` | 99.5% / 92.9% | todo |
| M3 | **tracker** — Jira, GitHub Issues | 48.1% median commit→work-item; 89% issue→epic in Jira | todo |
| M4 | **test** — `test → module`, `test → run` | 65.9% pooled | todo |
| M5 | **gherkin** — `Scenario → step → test` | **unmeasured — 0/19 clones have any `.feature`** | todo |
| M6 | **grafana** — `release → incident` | mixed | todo |

**M1 note** — consume graphify's JSON output behind our own interface; do **not**
fork it. It is Apache-2.0 and could be forked, but it runs at ~1,342 commits per
four months, so forking means permanent merge cost against a project improving
faster than we would. The Python/TypeScript split makes the process boundary
natural rather than a compromise.

**M1 caveat** — M1 alone does **not** prove the thesis. It is graphify with a
different query layer. The differentiators only appear at M2+ when SDLC edges
exist. Expect it to convince nobody but us that the architecture is right; its
value is day-one utility for coding agents via MCP, which is what drives adoption.

**M5 note** — Gherkin is the only intent artifact with a grammar, so
`Scenario → step → test` is `EXTRACTED` rather than `INFERRED`. That property is
real. But it is a first-class connector, **not** the spine — 0 of 19 clones
contain a `.feature` file.

---

## Open questions — answer before committing to M3–M6

`INFERENCE` Every intent artifact this architecture relies on — ADR, PRD,
acceptance criteria, Gherkin — is absent from 100% of the repositories measured.
The only positive evidence is one live Jira with structured AC blocks, n=3. That
pattern is a signal, not corpus noise, and it decides whether the intent tier has
any left-hand nodes at all.

| ID | Question | Method | Consequence if negative |
|---|---|---|---|
| Q1 | What share of projects in a **real** estate have `.feature` files? | Count in the customer's org | M5 drops out; Gherkin is a niche connector |
| Q2 | What share of Jira tickets carry structured, individually addressable acceptance criteria? | Sample the customer's Jira | Intent tier has no left-hand nodes; Specera is a delivery graph and must be positioned as one |
| Q3 | Recursive-CTE p95 on a filtered 3-hop traversal over 10⁶ edges | Benchmark before M2 | If > 200 ms the no-graph-database call fails and storage must be revisited |
| Q4 | Does a 9-tool MCP surface beat a 17-tool one? | 50-question eval over the same service layer | Raise the cap |

`INFERENCE` Q1 and Q2 are cheap and should run in week 1, not at M3. If both come
back near zero the product is still viable but is a different product, and
learning that early is worth more than any code written in the meantime.
