# Stack — S3: MCP, API, and agent-facing surfaces

Scope: MCP server, its tool surface, the HTTP API, webhook ingestion, auth.
Agents are the primary consumer; the dashboard is a client of the same core.

## 0. Liveness / licence table — every dependency recommended below

`FACT` All rows from `gh api repos/<r>` on 2026-08-04 (unauthenticated
`api.github.com` was rate-limited; `gh api` is the same endpoint authenticated).

| Dependency | Role | SPDX | Stars | Last push | Archived | Verdict |
|---|---|---|---|---|---|---|
| `modelcontextprotocol/typescript-sdk` | MCP server | **NOASSERTION** (see §1) | 13053 | 2026-08-04 | false | **adopt** |
| `modelcontextprotocol/python-sdk` | (rejected) | MIT | 23875 | 2026-08-03 | false | reject, §1 |
| `PrefectHQ/fastmcp` | (rejected) | Apache-2.0 | 27047 | 2026-08-03 | false | reject, §1 |
| `fastify/fastify` | HTTP API | MIT | 36924 | 2026-08-03 | false | **adopt** |
| `fastify/fastify-swagger` | OpenAPI emit | MIT | 1091 | 2026-07-23 | false | adopt |
| `turkerdev/fastify-type-provider-zod` | Zod→JSON Schema | MIT | 587 | 2026-08-02 | false | adopt, low bus factor |
| `colinhacks/zod` | schema source of truth | MIT | 43394 | 2026-07-30 | false | adopt |
| `scalar/scalar` | API reference UI | MIT | 15807 | 2026-08-03 | false | adopt |
| `stoplightio/spectral` | OpenAPI lint in CI | Apache-2.0 | 3172 | 2026-08-04 | false | adopt |
| `octokit/webhooks.js` | GH sig verify | MIT | 349 | 2026-08-02 | false | adopt (inlineable) |
| `panva/jose` | Jira OAuth webhook JWT | MIT | 7731 | 2026-08-03 | false | adopt |
| `ory/polis` (was `boxyhq/jackson`) | SAML | Apache-2.0 (LICENSE read) | 2257 | 2026-07-27 | false | **v1.1 only**, §5 |
| `better-auth/better-auth` | OIDC/session | MIT | 29449 | 2026-08-03 | false | adopt for v1 |
| `honojs/hono` | runner-up to Fastify | MIT | 31564 | 2026-08-03 | false | runner-up |
| `trpc/trpc` | (rejected) | MIT | 40489 | 2026-07-26 | false | reject, §3 |
| `apollographql/apollo-server` | (rejected) | MIT | 13941 | 2026-08-03 | false | reject, §3 |

`FACT` **`boxyhq/jackson` no longer exists under that name** — `gh api
repos/boxyhq/jackson` resolves to `ory/polis`. The brief cites it as what
sourcebot and Greptile use. It changed hands. `curl .../ory/polis/main/LICENSE`
→ Apache License 2.0. Permissive, no copyleft consequence, but a transferred
project is a liveness question, not a settled one.

`FACT` No copyleft anywhere above. No GPL/AGPL/SSPL/FSL/PolyForm in this tier.

## 1. MCP server: TypeScript SDK, stdio + Streamable HTTP, one build function

**Decision: `@modelcontextprotocol/sdk` (TypeScript), v1.30.0.**

- `FACT` Licence is messy and must be flagged to legal: GitHub reports
  `NOASSERTION`; the LICENSE file says the project *"is undergoing a licensing
  transition from the MIT License to the Apache License 2.0"* and that
  un-relicensed contributions *"remain licensed under the MIT License"*. Both
  outcomes are permissive — no product consequence — but no single SPDX id can
  be recorded for it. Same text in the Rust, Go and C# SDK LICENSE files.
- `FACT` Version churn is the deciding factor, not popularity. PyPI `mcp` is at
  **2.0.0**; npm `@modelcontextprotocol/sdk` is at **1.30.0** (79 releases, no
  major break). graphify pins `mcp>=1,<3` and branches at runtime:
  `graphify/serve.py:1344` — *"mcp 1.x exposes the `@server.list_tools()` …
  decorator API, mcp 2.x replaced it with `on_list_tools=` constructor
  callbacks."* That is a live maintenance tax we can decline.
- FastMCP is a third-party layer over a churning 2.x base. Reject: it adds a
  dependency whose API is downstream of two others.
- This does **not** dictate the extraction tier's language. graphify is already
  consumed out-of-process (it emits `graphify-out/graph.json`) and serena's
  `solidlsp` is an LSP subprocess. The agent-facing tier is TypeScript; the
  dashboard is TypeScript; Zod schemas are therefore shared between the MCP
  `outputSchema`, the REST OpenAPI, and the dashboard client. One schema, three
  surfaces.

**Transport: stdio (default) + Streamable HTTP (hosted). No SSE.**
`FACT` Spec revision `2026-07-28` ships exactly two transport documents —
`basic/transports/stdio.mdx` and `basic/transports/streamable-http.mdx`
(`gh api repos/modelcontextprotocol/modelcontextprotocol/contents/…`). SSE-only
is gone. Do not ship the legacy `GET /sse` + `POST /messages` pair GitNexus
still carries (`GitNexus/gitnexus/src/mcp/http-transport.ts:5-6`).

**One codebase, both modes:** a single `buildSperaServer(deps)` returning a
configured `Server`, with two thin transport bindings. `FACT` Both study repos
do exactly this and both comment on why — graphify `serve.py:1275-1281`
(*"Build the configured low-level MCP Server (shared by every transport)"*) and
GitNexus `http-transport.ts` reusing `createMCPServer` from `server.ts`.
Multi-user state (tenant, principal, confidence policy) is per-request context
resolved from the token, never module-global — graphify's per-request rebinding
(`serve.py:1322-1343`) is the shape, its process-global variable is not.

**Hosted defaults, copied from GitNexus's header comment
(`http-transport.ts:16-21`) because they are correct:** bind `127.0.0.1`;
refuse to start on `0.0.0.0` without auth; CORS restricted to loopback when
unauthenticated; `timingSafeEqual` on any secret compare.

## 2. The tool surface — 9 tools, hard cap 12

**Position on granularity: one tool per *question an agent asks*, not one per
graph primitive.** graphify ships 10, GitNexus ships ~19 (`list_repos, query,
cypher, context, detect_changes, check, rename, impact, explain, pdg_query,
route_map, tool_map, shape_check, api_impact, group_list, group_sync, trace`,
plus aliases — `GitNexus/gitnexus/src/mcp/tools.ts`).

`UNVERIFIED` (secondary reporting of a Speakeasy Pet Store experiment, not run
by me): perfect selection at 10 tools, 19/20 at 20 tools, total collapse at 107.
`VENDOR CLAIM` GitHub Copilot cut 40 tools → 13 for 2–5pp accuracy and −400ms.
`INFERENCE` The direction is consistent enough to design against even though I
could not reproduce the numbers; 9 leaves headroom under every reported cliff.

**Three rules that do most of the work:**
1. **No raw query-language tool.** GitNexus exposes `cypher`
   (`tools.ts:201`). We must not. It is a string-concatenation sink fed by
   untrusted repo/ticket text, and it bypasses the confidence default entirely —
   the one property the product is built on.
2. **Do not duplicate another server's surface.** graphify spends 3 of its 10
   tools on `list_prs` / `get_pr_impact` / `triage_prs`. Agents already have a
   GitHub MCP server. Specera answers *graph* questions about a PR, not "list
   PRs". This alone saves two slots.
3. **Modes, not tools.** `shortest_path` is `trace` with two endpoints;
   `god_nodes` is `stats` with a mode; `get_community` is `neighbors` with a
   filter.

| # | Tool | One-line contract |
|---|---|---|
| 1 | `specera_search` | Free text / external id / file path → ranked typed node refs. The entry point; everything else takes ids. |
| 2 | `specera_get` | Fetch nodes by id (batched) with attributes and source references. |
| 3 | `specera_neighbors` | One-hop expansion from node ids, filtered by predicate + direction; `group_by=community` covers cluster reads. |
| 4 | `specera_trace` | **The spine.** From any node, walk `AC → Scenario → Step → Test → Run → Commit → MergeCommit → Release → Incident` in either direction; optional `to` endpoint makes it shortest-path. |
| 5 | `specera_coverage` | The inverse: return the *missing* edges — ACs with no scenario, scenarios with no test, releases with untested ACs. What governance policy runs on. |
| 6 | `specera_impact` | Given a PR / commit / changed-file set, what ACs, scenarios, tests, releases and incidents are downstream. |
| 7 | `specera_policy_check` | Evaluate named policies against a ref — **always the base branch** — returning verdict + evidence chain + customer-side verification instructions. Never posts a check. |
| 8 | `specera_provenance` | For an edge or claim: extractor + version, rule, source artifact + locator + merge commit, ingest run, confidence. The "why should I believe this" tool. |
| 9 | `specera_stats` | Inventory and health: counts by type, EXTRACTED:INFERRED ratio, per-connector freshness, last ingest, most-connected nodes. |

Reserve slots 10–12 for `specera_diff` (graph delta between two refs) and
`specera_attestation`. Past 12, split into a second server rather than grow.

## 3. Provenance in the response schema — required, not optional

Every tool declares an `outputSchema` (`FACT` supported since spec §Tools:
*"`outputSchema`: Optional JSON Schema defining expected output structure"*) and
returns a shared envelope in `structuredContent`:

```jsonc
{ "query": { "confidence": "high", "as_of": "merge_commit:9f2c…" },
  "results": [ { "…": "node or edge payload",
      "provenance": {                       // REQUIRED on every result object
        "mode": "EXTRACTED",                // EXTRACTED | INFERRED | AMBIGUOUS
        "confidence": 0.98,
        "extractor": "gherkin@33.1.0", "rule": "scenario-step",
        "source": { "artifact": "repo://…/login.feature", "locator": "L12-L18",
                    "commit": "<merge sha, never head>" },
        "ingest_run": "run_01J…", "observed_at": "2026-08-04T…Z" } } ],
  "omitted": { "inferred": 14, "ambiguous": 3, "reason": "confidence_filter" },
  "degraded": false,
  "untrusted_fields": ["results[*].title", "results[*].description"] }
```

- **`provenance` is `required` in the JSON Schema.** A result that cannot carry
  provenance cannot be returned. This is the whole differentiator; making it
  optional makes it decorative.
- **Default is `confidence: "high"` = `EXTRACTED` only.** `include_inferred` /
  `include_ambiguous` are explicit booleans; setting either sets
  `degraded: true` **and** prefixes every affected row in the text rendering
  with `INFERRED:` / `AMBIGUOUS:`.
- **`omitted` is always present.** Silent filtering is the failure mode — an
  agent must be able to tell "nothing exists" from "14 things were hidden".
- **Text and structured output must both carry labels.** `FACT` The spec says a
  tool returning structured content SHOULD also return serialized JSON in a
  TextContent block; many clients read only text. graphify's flat line format
  (`serve.py:986-991`, `NODE <label> [src=… loc=… community=…]`) is the right
  shape — extend it with `prov=EXTRACTED conf=0.98`.
- All tools annotate `readOnlyHint: true, destructiveHint: false,
  openWorldHint: false`. `FACT` The spec warns clients MUST treat annotations as
  untrusted unless the server is trusted — so annotations are a hint, not our
  control. §6 is the control.

## 4. HTTP API — REST + OpenAPI 3.1 on Fastify

**Decision: Fastify + Zod → OpenAPI 3.1, served at `/api/v1`, Scalar for docs,
Spectral lint in CI.**

| Option | Verdict |
|---|---|
| **REST + OpenAPI 3.1** | **Adopt.** The spec document *is* the enterprise deliverable: language-agnostic, versionable, diffable in CI, generates clients for the Python/Java/Go estates that will integrate. Cache-friendly, and per-endpoint audit logging is trivial. |
| tRPC | **Reject.** TypeScript-only client, no published contract artifact. A customer's Python CI job cannot consume it. Directly fails "documented, stable, language-agnostic". |
| GraphQL | **Runner-up, reject.** Tempting for a graph, wrong here: (a) it hands customers an unbounded query planner over a governance DB — depth/complexity limiting becomes a permanent security workstream; (b) per-field provenance and a high-confidence *default* fight the resolver model; (c) every request is `POST /graphql`, so audit answers "who queried what" with one useless line. |
| Fastify vs Hono vs Nest vs Express | Fastify: JSON-Schema-native, so the response serializer *enforces* the provenance envelope on the way out. Hono is the runner-up and wins only if edge/Workers deployment matters — it does not for self-hosted enterprise. Nest's DI buys nothing here; Express has no schema-first story. |

**MCP tools and REST routes are both thin adapters over one internal service
layer.** Not MCP-calls-REST-over-HTTP (extra hop, auth confusion, doubled
latency), not duplicated logic. The envelope in §3 is produced by core, so both
surfaces get provenance for free and neither can forget it.

## 5. Webhook ingestion — verify, persist, 202, reconcile

| Concern | Decision |
|---|---|
| GitHub signature | `FACT` HMAC-SHA256 hex digest of the raw body in `X-Hub-Signature-256`, sent only when a secret is configured. Constant-time compare. Fastify `addContentTypeParser` must retain the raw buffer — verifying a re-serialized body is the classic bug. `@octokit/webhooks` (MIT) or ~20 inlined lines. |
| Jira signature | `FACT` **Two mechanisms, both required.** Admin/REST-registered webhooks send a WebSub-style HMAC in `X-Hub-Signature` (`sha256=…`). OAuth 2.0 app webhooks instead send a **bearer JWT in `Authorization`, signed with the app client secret** — verify with `jose`. Connect-descriptor webhooks are signed with the app `sharedSecret`. Anyone who implements only HMAC will silently accept unverified OAuth-app deliveries. |
| Replay | GitHub signs no timestamp, so signature validity alone cannot bound age. Primary control is the idempotency store; secondary is a receive-time window on the source's own `updated_at`. |
| Idempotency | `FACT` `X-GitHub-Delivery` is a GUID **stable across redeliveries** — so it is simultaneously the dedupe key and useless as a replay nonce. Key on `(source, delivery_id, sha256(raw_body))`: identical bytes → no-op; same id with *different* bytes → security alert, not an update. |
| Processing | `verify → persist raw envelope append-only → 202 → async worker`. GitHub times out ~10s. The raw table doubles as audit evidence and as the replay source. |
| Ordering | Webhooks arrive out of order. Version every graph write by the source's own monotonic field (Jira `fields.updated`, GitHub `updated_at`); drop stale writes. Never assume arrival order. |
| Backfill | Webhooks are lossy (outages, app installed after the fact, air-gapped windows). Every connector ships a cursor-based reconciler + full-resync command, and all graph writes are upsert-by-natural-key so backfill and webhook can race safely. A webhook-only ingestion path is a defect. |

Endpoint `POST /api/v1/webhooks/{github|jira}` requires **no bearer token** —
the shared secret is the credential. It is the one unauthenticated route and
must be rate-limited and body-size-capped independently.

## 6. Untrusted input — the MCP surface must not be an escalation path

`FACT` 10 of 19 clones ship agent-directive files; `GitNexus/.mcp.json` carries
an unpinned `npx -y gitnexus@latest mcp` plus a checked-in
`enableAllProjectMcpServers: true` allowlist (`.spike/findings-supply-chain.md`).
Everything Specera ingests — repo files, Jira summaries, PR bodies, commit
messages, branch names — is attacker-controlled text that will be pasted into an
agent's context by our tools.

1. **Read-only by construction.** Zero side-effecting tools in v1. No tool
   writes to GitHub, Jira, or the graph. Injected instructions have nothing to
   escalate into. GitNexus needs a whole `read-only-policy.ts` with an env flag
   and an allowlist of 14 tool names, precisely because its default surface
   includes `rename` and `group_sync`. Not having writes beats gating them.
2. **Sanitise every field of external origin before it reaches output.** `FACT`
   graphify already does this and names the threat: `graphify/serve.py:970-977`
   — *"Every LLM-derived field passes through `sanitize_label` before being
   concatenated into MCP tool output (F-010): an attacker who controls a corpus
   document can otherwise inject ANSI escapes, fake `graphify-out` log lines, or
   prompt-injection markup into the model's context"* (impl:
   `graphify/security.py:394`). Strip C0/C1 control chars and ANSI, cap per
   field, and never interpolate external text into the server's own narrative
   sentences — it goes inside a delimited block, listed in `untrusted_fields`.
3. **Never return agent-directive file bodies.** `CLAUDE.md`, `AGENTS.md`,
   `.cursorrules`, `.mcp.json`, `.claude/**`, `.github/copilot-instructions.md`
   are indexed as `AgentDirective` nodes — "this repo ships 48 agent directives
   and an unpinned `npx @latest` MCP server" is a *governance finding worth
   surfacing* — but their contents are never rendered through any tool.
4. **Output budget per call.** GitNexus has a dedicated `output-budget.ts`;
   graphify threads `token_budget` through every tool. Adopt: a hard cap makes
   context-flooding a non-attack.
5. **Repository allowlist on the hosted server**, resolved from the token's
   tenant, not from a tool argument. GitNexus does this via
   `repository-policy.ts` reading `GITNEXUS_MCP_ALLOWED_REPOS`; env is fine
   locally, but hosted multi-tenant scoping must come from the principal.

## 7. Auth — four callers, four mechanisms

| Caller | Mechanism | Why |
|---|---|---|
| Local CLI / IDE, stdio MCP | **No network auth at all.** Process runs as the user against a local graph; OS file permissions are the boundary. | Inventing a local token adds a secret to steal and buys nothing. Bind no port. |
| Hosted MCP, Streamable HTTP | **OAuth 2.1 resource server.** `FACT` spec `2026-07-28`: MCP servers **MUST** validate the token audience per RFC 8707 §2, advertise auth servers via RFC 9728 protected-resource metadata, and **MUST NOT** accept tokens not issued by their own AS. | Static API keys are non-conformant on this endpoint. Delegate the AS to the same IdP as the dashboard. |
| CI job | Short-lived token exchanged from the CI's **OIDC identity** (`id-token: write`), bound to `job_workflow_ref`. No long-lived PAT in CI secrets. | Composes with `security.md` §1's trusted-builder allowlist, which already keys on `job_workflow_ref`. |
| Dashboard | OIDC session via better-auth (MIT). SAML deferred to v1.1 via `ory/polis` (Apache-2.0) — flagged because it is a *transferred* project (was `boxyhq/jackson`). | Shipping OIDC-only in v1 is honest and lets SAML be earned. |
| Machine integrations, REST | Scoped bearer tokens: hashed at rest, `spec_` prefix for secret scanners, per-token scope + expiry, revocable, every use audit-logged. Distinct namespace from MCP tokens. | |

**Merge gate.** `FACT` `security.md` §2.4: a required status check trusts the
API call that sets it, so a Specera-posted check proves nothing. Therefore the
API's only job is `GET /api/v1/attestations/{merge_commit_sha}` returning a
detached-signature bundle, and the required check is `specera verify` running
**in the customer's CI against a trust root the customer holds**. The verifier
must succeed **offline** given bundle + trust root: no callback to Specera, so
Specera is out of the availability path and air-gapped installs work unchanged.

**Least-privilege scopes per surface.**

| Surface | GitHub | Jira |
|---|---|---|
| MCP server (all transports) | **none** — reads Specera's graph only | **none** |
| REST read API | none | none |
| Ingest, slice 1 (Gherkin spine) | `contents:read` + `metadata:read`, **enrolled repos only** | none |
| Ingest, slice 2 (delivery spine) | + `pull_requests:read`, Actions `artifacts:read` (JUnit XML) | none |
| Ingest, slice 3 (tracker spine) | unchanged | `read:jira-work` only |
| Webhook receiver | none (shared secret is the credential) | none |
| Attestation service | **none** — the informational check would need `checks:write`; do not request it in v1 | none |
| **Never** | `contents:write`; branch-protection **bypass actor** (`security.md` §3: GitHub's own agent requires it, which *weakens* the control set) | `write:jira-work` |

---

## Recommendations

- **MCP:** `@modelcontextprotocol/sdk` (TS, v1.30.0), stdio + Streamable HTTP
  from one `buildSperaServer()`; no SSE.
- **Tools:** 9, hard cap 12; no raw query language; no duplication of the GitHub
  MCP server; provenance `required` in every `outputSchema`; `EXTRACTED`-only by
  default with an always-present `omitted` count.
- **API:** REST + OpenAPI 3.1 on Fastify with Zod-derived schemas; GraphQL is
  the runner-up and is rejected on query-planner exposure and audit granularity.
- **Webhooks:** verify → persist raw → 202 → async, idempotent on
  `(source, delivery_id, body_hash)`, with a cursor reconciler per connector.
  Implement **both** Jira mechanisms (HMAC *and* OAuth-app bearer JWT).
- **Auth:** nothing local, OAuth 2.1 resource server hosted, CI OIDC exchange,
  OIDC dashboard; customer-side offline verifier for the merge gate.

**Biggest risk.** The 9-tool cap rests on secondhand benchmark reporting I could
not reproduce, and 9 tools over an ontology of ~30 node types means each tool
carries more parameters — parameter-selection error can replace tool-selection
error and be harder to see. *Experiment:* build the 9-tool surface and a
17-tool GitNexus-shaped variant over the same core, run a fixed 50-question
traceability eval against both, measure first-call tool accuracy **and**
first-call argument validity. Ship whichever wins; this is cheap because both
are adapters over the same service layer.

**Could not verify.** (1) Whether `ory/polis` preserves BoxyHQ Jackson's SAML
feature set and upgrade path post-transfer — check before v1.1, not before v1.
(2) Whether Jira admin-webhook HMAC covers every event type or only a subset.
(3) The Speakeasy tool-count numbers (secondary source only). (4) A single SPDX
id for the MCP TypeScript SDK — legal should read the LICENSE text directly.
