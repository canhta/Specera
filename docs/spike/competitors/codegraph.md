# CodeGraph (colbymchenry/codegraph, OSS CLI + MCP)

A local-first TypeScript CLI with a Rust extraction kernel that tree-sitter-parses ~41 languages into a SQLite database (`nodes` / `edges` / `files` / `unresolved_refs`, FTS5), resolves references through a staged precise→fuzzy matcher plus 15 framework route resolvers and dynamic-dispatch synthesizers, and serves 8 MCP tools tuned to keep an agent from falling back to Read/Grep.

## 1. Verdict

`FACT` CodeGraph is the only one of the six that treats **agent behaviour** as the optimisation target and measures it: `docs/benchmarks/`, `scripts/agent-eval/` (48 scripts), `__tests__/evaluation/`, a published per-language cross-file coverage table (`README.md`, "Measured cross-file coverage"), and a documented A/B methodology that pins the model to Sonnet on purpose as "the deliberate floor model" (`CLAUDE.md`). `FACT` It is MIT-licensed (`LICENSE`, © 2026 Colby Mchenry), single-binary, zero-native-build (`node:sqlite`), and stores everything in one SQLite file per project. `FACT` What kills it as a Specera component: the schema is deliberately generic — 22 node kinds, **12 edge kinds**, and **no confidence or resolution-strategy column on `edges`** (`src/db/schema.sql:45-56`) — so a 0.5-confidence fuzzy name match and a 0.95 import-resolved edge are byte-identical rows. `INFERENCE` Combined with a coverage metric that measures only *recall* ("share of files with ≥1 resolved cross-file dependent"), the false-edge rate is both unmeasured and unrecoverable from the data. `FACT` The OSS repo is an explicit loss-leader: `README.md:47` "**The CodeGraph platform is coming** — for every PR, know exactly what to test, what could break, which flows are affected" with a waitlist at getcodegraph.com.

## 2. Core architecture and unique mechanism

**Pipeline** (`CLAUDE.md`, "Layered pipeline"):
`files → ExtractionOrchestrator (tree-sitter) → SQLite (nodes/edges/files) → ReferenceResolver (imports, name-matching, framework patterns) → GraphQueryManager / GraphTraverser → ContextBuilder`

**Storage.** `FACT` SQLite via Node's built-in `node:sqlite` (`DatabaseSync`) with WAL + FTS5, "no native build step and no wasm fallback" (`CLAUDE.md`, module layout); per-project data in `.codegraph/`. Schema is 194 lines, `src/db/schema.sql`:
- `nodes(id, kind, name, qualified_name, file_path, language, start_line, end_line, start_column, end_column, docstring, signature, visibility, is_exported, is_async, is_static, is_abstract, decorators, type_parameters, return_type, updated_at)` — `:20-42`
- `edges(id, source, target, kind, metadata, line, col, provenance)` with FK cascade to nodes — `:45-56`
- `files(path, content_hash, language, size, modified_at, indexed_at, node_count, errors)` — `:59-68`
- `unresolved_refs(id, from_node_id, reference_name, reference_kind, line, col, candidates, file_path, language, status, name_tail)` — `:79-92`
- `nodes_fts` FTS5 virtual table with insert/update/delete triggers — `:108-134`
- `name_segment_vocab(segment, name)` — lowercased word segments of symbol names ("OrderStateMachine" → order, state, machine) so natural-language prompt words can be verified against the graph; FTS can't serve it because its tokenizer keeps camelCase as one token — `:136-153`
- `project_metadata(key, value, updated_at)` — `:190`

`FACT` Edge identity is `UNIQUE(source, target, kind, IFNULL(line,-1), IFNULL(col,-1))` (`:173-174`), added because `INSERT OR IGNORE` with nothing to conflict on had been producing byte-identical duplicate rows that "inflated counts and flowed into callers/impact (#1034)".

**Node kinds — 22** (`src/types.ts:22-45`): `file, module, class, struct, interface, trait, protocol, function, method, property, field, variable, constant, enum, enum_member, type_alias, namespace, parameter, import, export, route, component`.

**Edge kinds — 12** (`src/types.ts:56-69`): `contains, calls, imports, exports, extends, implements, references, type_of, returns, instantiates, overrides, decorates`.
`FACT` Array order is part of the native kernel's wire contract — kinds cross the FFI boundary as indexes (`src/types.ts:52-55`, `src/extraction/kernel/layout.ts`); "append new kinds, never reorder".

**Parser strategy.** `FACT` tree-sitter throughout, split across two implementations: a **Rust kernel** (`codegraph-kernel/src/`: `python.rs, go.rs, java.rs, rustlang.rs, csharp.rs, php.rs, ruby.rs, swift.rs, kotlin.rs, dart.rs, scala.rs, lua.rs, rlang.rs, ccpp/, tsjs/`) and TypeScript extractors (`src/extraction/languages/`), with a parity checker (`scripts/kernel-parity.mjs`) and per-language "kernel port checklist" design docs (13 of them in `docs/design/`). `FACT` Non-tree-sitter formats get hand-written extractors: `svelte-extractor.ts`, `vue-extractor.ts`, `liquid-extractor.ts`, `dfm-extractor.ts` (Delphi forms) (`CLAUDE.md`). `FACT` `LANGUAGES` is 41 entries plus `unknown` (`src/types.ts:77-121`), including `yaml`, `xml`, `properties`, `terraform`, `nix` — configuration formats counted as languages.

**Reference resolution — staged, with an ambiguity ceiling.** `FACT` `src/resolution/` = `import-resolver.ts` (86 KB, tsconfig path aliases + cargo workspace member globs), `name-matcher.ts` (103 KB), `frameworks/` (Express, Laravel, Rails, FastAPI, Django, Flask, Spring, Gin, Axum, ASP.NET, Vapor, React Router, SvelteKit, Vue/Nuxt, Cargo workspaces), `callback-synthesizer.ts` (180 KB), `c-fnptr-synthesizer.ts` (67 KB).
- `FACT` Strategies are labelled *precise* vs *fuzzy* in-source (`name-matcher.ts:10-27`). Precise: qualified-name, import-based, class-name. Fuzzy: `matchByExactName`'s `findBestMatch` and `matchMethodCall` Strategy 3, scoring by directory proximity and receiver-word overlap.
- `FACT` `AMBIGUOUS_NAME_CEILING` defaults to 500 (`name-matcher.ts:28`, tunable via `CODEGRAPH_AMBIGUOUS_NAME_CEILING`): above that many same-named definitions the fuzzy strategies decline rather than "emitting a low-confidence, almost-certainly-wrong edge". The comment is candid that this exists partly for an O(K²) performance blow-up that "pinned a core for 15-28 min at 'Resolving refs … 94%'" (#999).
- `FACT` Each resolution produces a numeric `confidence` (0.5 for a cross-language single match, 0.9 same-language single match, 0.95 exact path match — `name-matcher.ts:66-71`, `:416-422`) and a `resolvedBy` tag (`framework` 82 sites, `import` 18, `qualified-name` 5, `function-ref` 5, `exact-match` 5, `file-path` 4, `instance-method` 3, `fuzzy` 1).
- `FACT` **Neither `confidence` nor `resolvedBy` is a column in `edges`** (`schema.sql:45-56`). The only provenance signal that survives to storage is `provenance TEXT DEFAULT NULL`, and the only value written anywhere in `src/` is `'heuristic'` (5 call sites).
- `FACT` Interface / inheritance dispatch has edge kinds (`implements`, `overrides`, `extends`) but no MRO phase; there is no DI-container resolver. Dynamic dispatch is handled by **synthesizers** for specific channels — "callback/observer, EventEmitter, React re-render (`setState`→`render`), JSX child (`render`→child component), django ORM descriptor" — all emitted as `provenance:'heuristic'` with `metadata.synthesizedBy` + `registeredAt` (`CLAUDE.md`, "Dynamic-dispatch coverage").

**Unresolved-reference lifecycle.** `FACT` `unresolved_refs` rows start `pending`; a resolution pass either deletes the row (resolved) or marks it `failed`, keeping it "so a later sync can retry it when a changed file introduces a symbol that could satisfy it (#1240)", with `name_tail` (last dotted segment) written on failure to make the retry lookup work (`schema.sql:70-92`). `INFERENCE` This is the cleanest handling of "we couldn't resolve this yet" in the six repos — it is durable, queryable, and self-healing.

**Incremental.** `FACT` `files.content_hash` + `CodeGraph.sync()` (`src/index.ts:742+`) re-extracts changed files only, runs cross-file finalisation passes on every sync that touched files "so edits to `app.module.ts` propagate to controllers in unchanged files", and re-runs the failed-ref retry. A native file watcher (`src/sync/`, FSEvents/inotify/RDCW with debounce) and git-hook helpers drive it. WAL auto-checkpointing is deferred for the whole run because "the cost scales with the EXISTING database size, not the change size" (#1248). `INFERENCE` This is genuinely incremental at the file level — the only one of the six where re-parse, re-resolve, and stale-row cleanup are all diff-driven.

**Query surface.** `FACT` 8 MCP tools: `codegraph_explore`, `codegraph_node`, `codegraph_search`, `codegraph_callers`, `codegraph_callees`, `codegraph_impact`, `codegraph_files`, `codegraph_status` (`src/mcp/tools.ts`, 241 KB). `FACT` `codegraph_trace` and `codegraph_context` were **removed** because the agent under-picked them and a fuzzy-input tool "surfaced the wrong feature" (`CLAUDE.md`).

## 3. Strongest capabilities

- `FACT` **A published, per-language cross-file coverage table** (`README.md`) on named benchmark repos: Python/psf-requests 100%, PHP/guzzle 100%, Ruby/sidekiq 100%, Go/gin 96.6%, Kotlin/okhttp 96.2%, TS/self 95.8%, Swift/Alamofire 95.3%, C++/leveldb 94.8%, Vue-Nuxt/nuxt-movies 93.5%, Java/gson 93.3%, Astro 93.0%, Dart/flutter-packages 92.4%, Luau/Fusion 92.2%, C/redis 92.2%, Obj-C/SDWebImage 91.6%, Scala/gatling 91.2%, Rust/ripgrep 86.7%, C#/MediatR 85.2%, Lua/telescope 84.2%, Pascal/PascalCoin 77.4%, Liquid/Shopify-dawn 73.8%. Plus per-framework routing: Express/Flask/Axum/Vapor/React-Router 100% down to Django 74.1%, with the low ones explicitly called "their honest static-analysis ceiling".
- `FACT` **Durable unresolved-reference table with retry-on-change** (`schema.sql:70-92`) — the graph knows what it failed to resolve and heals when the missing symbol appears.
- `FACT` **Edge identity uniqueness enforced in SQL** (`schema.sql:173-174`), added after duplicate rows were found inflating impact results (#1034).
- `FACT` **Synthesized edges are labelled and traceable**: `provenance:'heuristic'` + `metadata.synthesizedBy` + `registeredAt` (the wiring site), surfaced inline in the tool output (`CLAUDE.md`).
- `FACT` **"Partial coverage is WORSE than none"** is an enforced engineering rule with measurement behind it: on excalidraw, adding the react-render bridge alone *raised* agent reads to 5–7; only adding the jsx-child hop dropped them to 0–1 (`CLAUDE.md`).
- `FACT` **A required validation methodology per language × framework**: small/medium/large real repos, ≥3 flow prompts, deterministic probes (`scripts/agent-eval/probe-{node,explore}.mjs`), node-count-explosion check, synthesized-edge precision spot-check, then an agent A/B with ≥2 runs per arm and a stated refusal to conclude from n=1 (`CLAUDE.md`).
- `FACT` **Repo-size-scaled retrieval budgets** with a stated monotonicity invariant: `getExploreBudget(fileCount)` → 1/2/3/4/5 calls at 500/5000/15000/25000 files, and "a larger tier must never get a smaller `maxCharsPerFile` than a smaller tier" — motivated by a real regression where the `<5000` tier's 2500 chars/file was below the `<500` tier's 3800 (`CLAUDE.md`).
- `FACT` **Errors are treated as a product risk**: `isError: true` is reserved for security refusals and real malfunctions because "one or two `isError: true` responses early in a session and the agent stops calling codegraph entirely"; every recoverable condition returns success-shaped guidance instead (`CLAUDE.md`).
- `FACT` Supply chain: npm provenance, signed and attested releases, `SHA256SUMS`, release built only by the GitHub Actions workflow with manual `npm publish` explicitly called wrong (`README.md` badges; `CLAUDE.md` Releases).

## 4. Critical weaknesses

- `FACT` **The edge table has no confidence, no `resolvedBy`, and no candidate set.** `schema.sql:45-56`. Resolution computes confidence 0.5–0.95 (`name-matcher.ts:66-71`, `:416-422`) and throws it away at write time. `INFERENCE` A consumer cannot filter to high-confidence edges, cannot audit why an edge exists (except for the 5 `'heuristic'` sites), and cannot distinguish a cross-language 0.5 guess from an import-resolved fact. For Specera — where the graph must underpin blast-radius claims a human acts on — this is disqualifying.
- `FACT` **Coverage measures recall only.** The README defines fair coverage as "the share of symbol-bearing source files that have at least one *resolved cross-file dependent*". A file with one correct dependent and fifty fabricated ones scores the same as a file with one correct dependent. `INFERENCE` No precision figure is published, and the schema does not retain the data needed to compute one after the fact.
- `UNVERIFIED` **The coverage table is not reproducible from the repo.** No script under `scripts/` computes it; the agent-eval harness measures Read/Grep/tool-call counts and LLM-judged verdicts, not coverage. Verifying would require the maintainer's unpublished measurement script or re-deriving the metric against each named repo. Treat the table as `VENDOR CLAIM`.
- `FACT` **12 edge kinds and no framework/runtime edge vocabulary.** Routes are `route` *nodes* wired with generic `references` edges (`CLAUDE.md`, "Frameworks emit `route` nodes and `references` edges"); there is no `injects`, `queries`, `handles_route`, `advised_by`, or equivalent. `INFERENCE` Framework semantics are encoded in node kind + metadata JSON, so a Cypher-equivalent question ("which controllers does the container inject repository X into") is not expressible.
- `FACT` **No cross-repository graph.** One `.codegraph/` per project; the MCP server can *query* a second project by `projectPath` (`README.md:458`, `:566`) but no edge ever spans two indexes. Service-to-service calls are invisible.
- `FACT` **Fuzzy matching is on by default up to 500 same-named definitions** (`name-matcher.ts:28`). The ceiling was introduced for a vendored-theme pathology, not because 499 candidates is safe.
- `FACT` **Reactive/reconciler runtimes are an acknowledged blind spot**: "Halo's `ReactiveExtensionClient`, MediatR, Vue Proxy … flows there have no static edges, so nothing surfaces (correctly — silent beats wrong)" (`CLAUDE.md`). Local data flow is also deliberately uncovered — "tracking every local would explode the graph".
- `FACT` **Telemetry is default-ON.** `TELEMETRY.md`: "The interactive installer asks up front with a visible default-on toggle and never re-asks"; opt-out via `codegraph telemetry off`, `CODEGRAPH_TELEMETRY=0`, or `DO_NOT_TRACK=1`. A daily GitHub update check also runs from the MCP server. `INFERENCE` Defensible for an OSS CLI, but a default-on outbound connection is a procurement conversation in most enterprises.
- `FACT` The README installs via `curl … | sh` / `irm … | iex` (`README.md`, Get Started). `INFERENCE` Piping a remote script to a shell is the install path most security teams block outright.
- `FACT` Node engine is pinned `>=20.0.0 <25.0.0` with a hard exit outside it (`CLAUDE.md`), and running from source requires Node ≥22.5 for `node:sqlite`.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | `CLAUDE.md` states it outright: "CodeGraph provides **code context**, not product requirements" |
| Jira/work tracking | No | No tracker integration in `src/` |
| Architecture/ADR | No | No document or decision node kind in `NODE_KINDS` (`src/types.ts:22-45`) |
| Implementation | Partial | 8 MCP tools + `codegraph_explore` flow reconstruction; read-only, writes no code |
| PR review | Partial | `codegraph affected` CLI subcommand and `codegraph_impact` MCP tool give blast radius; the PR product ("for every PR, know exactly what to test, what could break") is the **unreleased hosted platform** (`README.md:47`) |
| Test generation | No | — |
| Security/pentest | No | No taint or data-flow layer; `SENSITIVE_PATHS` / `PathRefusalError` protect the *tool*, not the target repo |
| Release | No | — |
| Monitoring/incidents | No | — |
| Maintenance/knowledge | Partial | Impact radius, callers/callees, path finding (`src/graph/GraphTraverser`), FTS5 search; no durable project memory |

## 6. Security, deployment, and license

- `FACT` **License: MIT** — `.spike/clones/codegraph/LICENSE`, 21 lines, "Copyright (c) 2026 Colby Mchenry", standard MIT text. `INFERENCE` No restriction on commercial reuse, vendoring, or forking; attribution only. Of the six, this is the most permissive licence attached to a working extractor.
- `FACT` Deployment: single self-contained binary (bundles its own Node runtime) or `npm i -g @colbymchenry/codegraph`; per-project SQLite in `.codegraph/`; MCP over stdio with an optional persistent daemon (`.codegraph/daemon.sock`, `CODEGRAPH_DAEMON_IDLE_TIMEOUT_MS`). No server, no tenancy, no auth model — it is a single-user local tool.
- `FACT` Egress: telemetry to a self-hosted Cloudflare Worker + D1 (`telemetry-worker/`, `telemetry-dashboard/`; HEAD commit `49c11fc` "Self-hosted telemetry on Cloudflare D1 + password-gated admin dashboard (CG-7)"), and a daily GitHub release check. Both individually disableable; `DO_NOT_TRACK=1` disables both. `FACT` The collected fields are documented as an exhaustive allowlist enforced at ingest, with the worker source in-repo (`TELEMETRY.md`): `machine_id` (random UUID), `codegraph_version`, `os`, `arch`, `node_major`, `ci`, `schema_version`, plus one of four event types.
- `FACT` No LLM calls in the indexing path — "Extraction is deterministic — derived from AST, not LLM-summarized" (`CLAUDE.md`).
- **Prompt-injection surface.** `FACT` MCP tool output includes full source bodies (`codegraph_node` "returns the full body + the caller/callee trail"; explore returns per-file source up to 7000 chars/file), so untrusted repo content flows into the agent verbatim. `UNVERIFIED` whether any sanitisation or delimiting is applied — verifying would require reading the response formatters in `src/mcp/tools.ts` and `src/context/`, not done here. `FACT` The security posture that *is* implemented is path-based: `SENSITIVE_PATHS`, `PathRefusalError`, and a symlink-resistance test (`__tests__/security.test.ts`, referenced in `CLAUDE.md`).

## 7. Ideas to adopt or avoid

### Adopt
- **A durable `unresolved_refs` table with a `pending → failed` lifecycle and retry-on-new-symbol** (`schema.sql:70-92`, `name_tail` for dotted refs). Specera should ship this exact structure: it makes recall loss a queryable number, makes the index self-healing across commits, and gives a free "resolution health" metric per repo.
- **A SQL UNIQUE index as the edge identity contract** (`schema.sql:173-174`) including the `IFNULL(line,-1)` fold so coordinate-less synthesized edges dedup too. The bug it fixed (duplicate edges inflating impact counts) is one Specera will otherwise ship.
- **`name_segment_vocab`** (`schema.sql:136-153`): a materialised (segment → symbol name) table so natural-language prompt words can be checked against the graph, because FTS tokenizers keep camelCase as one token. Cheap, and directly useful for routing a plain-English question to graph entry points.
- **Repo-size-scaled retrieval budgets with a monotonicity invariant** (`getExploreBudget` / `getExploreOutputBudget`). Any Specera context API must scale its output budget with corpus size and must be regression-tested for the non-monotonic tier bug described in `CLAUDE.md`.
- **"Partial coverage is worse than none" as a shipping rule.** Specera should not ship a half-bridged dynamic-dispatch channel; measure the end-to-end flow before and after.
- **Success-shaped errors for recoverable conditions.** Reserve hard errors for genuine refusals; return guidance otherwise. The observed failure mode ("the agent stops calling the tool entirely after one error") applies to any MCP surface Specera builds.
- **Publishing a per-language, per-framework coverage table with named benchmark repos and an explicitly stated denominator** — and then going further than CodeGraph by publishing precision alongside recall.
- **A parity checker between two extractor implementations** (`scripts/kernel-parity.mjs`) if Specera ever runs a fast path and a reference path.

### Avoid
- **Discarding resolution confidence at write time.** Persist `confidence`, `resolved_by`, and the candidate set on every edge. This is the single change that would most improve CodeGraph and the single thing Specera must not copy.
- **Counting config formats as languages.** `yaml`, `xml`, `properties`, `nix` in `LANGUAGES` (`src/types.ts:77-121`) inflates a "41 languages" claim.
- **A 12-kind edge vocabulary for a framework-aware product.** Route/DI/ORM/event semantics buried in `metadata` JSON cannot be queried or indexed.
- **Default-on telemetry plus `curl | sh` install** in anything aimed at enterprise buyers.
- **Fuzzy name matching up to 500 candidates.** If Specera keeps a fuzzy tier at all, it must be off by default, capped far lower, and every fuzzy edge must be flagged in the row.
- **One index per repo with no cross-index edges** — this forecloses the service-topology questions Specera exists to answer.

## 8. Build, borrow, buy, integrate, or reject

**Borrow.** MIT makes everything here reusable, and three artifacts are worth lifting: the `unresolved_refs` lifecycle table, the edge-identity UNIQUE index, and the `name_segment_vocab` trick — all small, all in `src/db/schema.sql`, all solving problems Specera will otherwise hit. The extraction kernel is also fair game but is one-language-per-file Rust with no interface-dispatch or DI resolution, so it is a starting point rather than an answer. Do not integrate CodeGraph as the engine: the 12-kind edge vocabulary and the discarded confidence make it impossible to build a defensible impact claim on top, and there is no cross-repo graph at all.

## 9. Evidence

- Commit read: `49c11fc` — `49c11fc 2026-08-01 Self-hosted telemetry on Cloudflare D1 + password-gated admin dashboard (CG-7) (#1497)`.
- Repo: https://github.com/colbymchenry/codegraph — 780 commits, first 2026-01-18, 744 in the last 6 months.
- Schema: `src/db/schema.sql` (194 lines, read in full) — `nodes` `:20`, `edges` `:45`, `files` `:59`, `unresolved_refs` `:79`, `nodes_fts` `:108`, `name_segment_vocab` `:149`, edge identity index `:173`, `project_metadata` `:190`.
- Vocabulary: `src/types.ts:22-45` (`NODE_KINDS`, 22), `:56-69` (`EDGE_KINDS`, 12), `:77-121` (`LANGUAGES`, 41 + `unknown`).
- Resolution: `src/resolution/name-matcher.ts:10-35` (ambiguity ceiling rationale), `:41-90` (`matchByFilePath`, confidence values), `:405-422` (`findBestMatch` candidate gate); `src/resolution/import-resolver.ts`, `src/resolution/callback-synthesizer.ts`, `src/resolution/c-fnptr-synthesizer.ts`, `src/resolution/frameworks/`.
- Provenance audit: `grep -rohE "provenance: *'[a-z-]+'" src/` → only `'heuristic'` (5 sites); `grep -n "confidence" src/db/queries.ts` → no persistence path.
- Kernel: `codegraph-kernel/src/` (16 language modules + `ccpp/`, `tsjs/`), `scripts/kernel-parity.mjs`, 13 `*-kernel-port-checklist.md` under `docs/design/`.
- Incremental: `src/index.ts:742+` (`sync()`), `src/db/wal-valve.ts`, `src/sync/`.
- Evaluation: `README.md` "Measured cross-file coverage" table; `docs/benchmarks/{call-sequence-analysis,codegraph-ab-matrix,answer-directly-vs-explore-agent}.md`; `scripts/agent-eval/` (48 files); `__tests__/evaluation/{runner,scoring,test-cases}.ts`.
- Docs read: `README.md`, `CLAUDE.md`, `TELEMETRY.md`, `LICENSE`, `src/db/schema.sql`, `src/types.ts`, `docs/design/` and `docs/benchmarks/` directory listings.
- Commands run (read-only; no install script, build, or test execution — `install.sh`/`install.ps1` were deliberately not executed): `git rev-parse --short HEAD`, `git log`, `find`, `grep`, `sed`, `head`, `wc`.
- Not verified: how the published coverage percentages were computed (no in-repo script found); whether MCP source-body output is sanitised against prompt injection.
