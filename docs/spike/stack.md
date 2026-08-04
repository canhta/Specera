# Stack — build decisions

Canonical stack selection for the open-source SDLC knowledge graph
([`product-proposal.md`](product-proposal.md), [`decision.md`](decision.md) §7).
Working notes: `.spike/stack-{monorepo,storage,api,dashboard,enterprise}.md`.

Every dependency below was checked for **licence (from the repo), last push, and
`archived` status**. That rule exists because this spike nearly built on Kuzu.

## 1. Decisions

| Area | Decision | Deciding evidence |
|---|---|---|
| Language | **TypeScript, Node 24 LTS**. Polyglot only across process boundaries | See the note below — the original rationale was voided by a later reordering, the decision survives on different grounds |
| Monorepo | **pnpm workspaces. Nothing else** | `FACT` **0 of 19** clones use Nx/Turborepo/moon/Bazel/Lerna/Rush. sourcebot runs a 7-package enterprise platform on bare workspaces |
| Storage | **Relational, no graph database.** `node:sqlite` (CLI) + PostgreSQL (server), recursive CTEs | Every embedded graph DB failed the gate — see §3 |
| Graph API | Base table `edges_raw`; **view named `edges` is confidence-filtered** | Makes forgetting to filter impossible rather than merely discouraged |
| MCP | `@modelcontextprotocol/sdk` (TS), stdio + Streamable HTTP, **9 tools, cap 12** | `FACT` Python SDK is at 2.0.0 vs TS 1.30.0 with no major break in 79 releases; graphify carries runtime branching for the 1.x/2.x split (`serve.py:1344`) |
| HTTP API | **REST + OpenAPI 3.1 on Fastify**, Zod-derived | Language-agnostic and documentable; tRPC rejected outright, GraphQL on query-planner exposure |
| Dashboard | **Vite + React SPA**, served as static assets by the API | Only option that adds no runtime to the deployment |
| Graph view | **Cytoscape.js** (MIT), hard cap 2,000 nodes / 5,000 edges, server-side layout | `FACT` codegraphcontext degrades to bare `fillRect` above 3,000 nodes (`CodeGraphViewer.tsx:752`) |
| Charts | **Recharts ^3** (MIT) | Highcharts / AG Charts / amCharts all report `NOASSERTION` and are commercial |
| Auth | **OIDC relying party only.** SAML/SCIM via a bridge container | Swapping the bridge is a container change, not a code migration |
| Tenancy | **Multi-tenant schema, single-tenant deployment** — `org_id` + RLS from migration 1 | Retrofitting tenancy is among the most expensive migrations there is |
| Observability | OpenTelemetry + pino, **default-off**, exports to the customer's collector | No-egress-by-default is the trust differentiator |
| Deploy | Digest-pinned Dockerfile + Compose + air-gap tarball in v1; Helm v1.1 | `FACT` **0 of 19** clones ship a `Chart.yaml` — Helm is the category's universal deferral |
| Release | Changesets `fixed`; one GitHub Release fans out to npm + GHCR + Helm; OIDC trusted publishing | |
| Test / lint | vitest (5/5 corpus convergence) · Biome · `tsc` project refs · zizmor/pinact/actionlint/secretlint | Workflow tooling lifted from repomix |

### 1.1 Language rationale — restated 2026-08-04

`INFERENCE` The original deciding evidence for TypeScript was *"`cucumber/gherkin`
ships 12 implementations and no Rust, and Gherkin is slice 1"*. **That reasoning
is void**: Gherkin was demoted from the first slice to connector M5 after `FACT`
0 of 19 clones were found to contain any `.feature` file
([`../roadmap.md`](../roadmap.md)). A conclusion whose stated reason has been
withdrawn must be re-argued, not silently retained.

Re-examined: the first connector is now **code**, and both candidate providers
(graphify, serena `solidlsp`) are **Python** — which would argue for Python if we
imported them. We do not; both are consumed across a process boundary, so the
host language is unconstrained by them.

TypeScript survives on three independent grounds, none of which involve Gherkin:

1. `FACT` The MCP TypeScript SDK is at 1.30.0 with **no major break across 79
   releases**, while the Python SDK is at 2.0.0 — graphify carries runtime
   branching for the 1.x decorator vs 2.x callback API (`serve.py:1344`). MCP is
   the primary surface, so SDK churn is a first-order risk.
2. `FACT` `node:sqlite` gives zero-native-build installs, verified running on
   Node v24.18.0 with no experimental warning (§2).
3. The dashboard and API are TypeScript regardless, so a Python core would add a
   language boundary inside our own codebase rather than at an external edge.

`INFERENCE` Runner-up remains Python (uv + hatchling). What would flip it: MCP's
Python SDK stabilising while the TS SDK churns, or a decision to import rather
than subprocess a Python provider.

## 2. Verified working, not merely designed

`FACT` Coordinator-run on Node v24.18.0, 2026-08-04. `node:sqlite` imports with
**no experimental warning**, and the two mechanisms that constitute Specera's
technical differentiation work in ~20 lines with zero dependencies:

```
filtered traversal: AC-1 -> SCEN-1 -> TEST-1 -> COMMIT-a -> REL-1  (depth 4)
edges_raw: 5   edges(view): 4   -> low-confidence excluded by default: 1
```

The full traceability chain traverses in one recursive CTE, and an `INFERRED`
edge at confidence 0.22 is excluded without the query mentioning provenance.

`INFERENCE` This is the structural answer to the round-1 finding that `FACT`
codegraph computes confidence (`import-resolver.ts:1271`) then discards it before
insert (`schema.sql:45-56`), while codegraphcontext and stakgraph store it and
never read it. Raw access requires typing `_raw`, is `REVOKE`d in Postgres, and
is CI-linted in SQLite.

## 3. Rejected, with reasons

**Storage — every embedded graph database failed:** `FACT` Kuzu `archived=true`
(2025-10-10) · Cozo dormant since 2024-12-04, one maintainer · Cayley last human
commit 2024-07-06 · IndraDB single maintainer · HelixDB pre-1.0 · **SurrealDB and
Memgraph are BSL 1.1** · **FalkorDB is SSPL v1** · Neo4j is GPL-3.0 and would
GPL-entangle Specera's own distribution. Licence files read directly.

**Tooling:** Nx also carries `GHSA-8mjq-32x3-22qf` (critical, "Malicious versions
of Nx were published", 2025-09-25). WorkOS rejected — a closed hosted dependency
makes the self-host and air-gap claim false at the login page.

**Scope of the potpie reuse is narrower than previously stated.** `FACT` potpie's
*engine* depends on SSPL FalkorDB. Only `context-core` (pydantic-only) is safe to
reuse — its per-type `freshness_ttl_hours` / `source_of_truth`
(`ontology.py:160-165`), `EVIDENCE_STRENGTHS` (`:92`), and the `invalid_at`
supersession rule (`:200-207`) that becomes our bitemporal edge.

## 4. Traps found in the corpus — do not repeat

`FACT`, each verified in a cloned repo or via API:

- **Identity drift**: `boxyhq/jackson` no longer exists under that name; it
  resolves to `ory/polis`. Pinning the old npm name from memory ships a dead
  dependency. Confirmed independently by three agents.
- **`grafana/oncall` is archived** (2026-03-24), successor cloud-only. Same class
  of trap as Kuzu, in a component this product would plausibly integrate.
- **graphify's `graph.html` loads vis-network from the unpkg CDN** — breaks
  air-gapped deployment outright.
- **sourcebot ships a hardcoded PostHog key as a zod default**
  (`packages/shared/src/env.server.ts:246`) with `SOURCEBOT_TELEMETRY_DISABLED`
  defaulting to `'false'` and an install ping in `entrypoint.sh:154`.
- **sourcebot's `auditLogPruner.ts` bulk-deletes audit rows on a timer** — Xray's
  mutable-history failure with a scheduler attached. Specera ships no pruner, ever.
- **sourcebot's `crypto.ts:9` uses unauthenticated `aes-256-cbc`** on the general
  path, reserving GCM only for OAuth; its Compose pins `:latest` with
  `pull_policy: always`, and its Dockerfile bakes Sentry/Langfuse endpoints at
  build time.

`INFERENCE` A correction to this spike's own brief belongs in this list: the
coordinator asserted as `FACT` that sourcebot uses BoxyHQ Jackson. It does not —
`git log -S'jackson' --all` and `-S'saml' --all` over 1,358 commits both return
zero, and `packages/web/package.json:168` pins `next-auth ^5.0.0-beta.32`. Found
by an agent, confirmed by the coordinator, and corrected in the brief.

## 5. Repository layout

```
specera/
├── packages/
│   ├── core/              graph engine, ontology, query layer
│   ├── connector-sdk/     published independently; connectors depend on this alone
│   ├── connectors/        github, jira, gherkin, grafana — plugins, never import core
│   ├── mcp/               MCP server (stdio + streamable HTTP)
│   ├── api/               Fastify + OpenAPI; serves the dashboard as static assets
│   ├── cli/               npx specera — zero native addons
│   └── dashboard/         Vite + React SPA
├── docs/
└── e2e/
```

`INFERENCE` Connectors depending only on `connector-sdk` is what makes
out-of-tree connectors the same artifact as in-tree ones. The ingestion pipeline
itself stays a **static typed DAG, not a plugin surface** — `FACT`
`GitNexus/ARCHITECTURE.md:119` explicitly chose "no plugins" there, and inverting
that is how a six-connector list becomes unmaintainable.

## 6. Open risks

| Risk | Mitigation | Retires when |
|---|---|---|
| TypeScript in the graph hot path — provenance filtering is a per-edge predicate on the hottest loop | Benchmark a filtered 3-hop traversal over 10⁶ edges before connector M2 (tracked as Q3 in [`../roadmap.md`](../roadmap.md)); if p95 > 200 ms the problem is storage, not language | Benchmark run |
| Two SQL dialects (SQLite + Postgres) is a permanent tax; one Postgres-only `jsonb` operator and the CLI diverges | CI conformance suite against both engines | PGlite matures enough to unify |
| Ory Polis has had no release since v26.2.0 (2026-03-20) and its commit stream is ~80% bot | OIDC-inward boundary — swapping to Keycloak is a container change | An Ory support commitment, or the swap |
| 9-tool cap rests on secondhand benchmark reporting | Run a 9-tool vs 17-tool variant over the same service layer, 50-question eval | Eval run |

`UNVERIFIED` Recursive-CTE performance at 10M+ edges is unmeasured. That is the
first number to get, because it decides whether the no-graph-database call holds.
