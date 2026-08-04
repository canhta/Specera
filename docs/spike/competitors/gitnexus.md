# GitNexus (abhigyanpatwari/GitNexus, OSS CLI + MCP)

A TypeScript monorepo that runs a 19-phase ingestion DAG over a repo (tree-sitter parse → scope resolution → MRO → DI → Leiden communities → process synthesis), persists a typed property graph into an embedded LadybugDB (ex-KuzuDB) file, and exposes it to agents over MCP with Cypher, impact, trace, and taint tools.

## 1. Verdict

`FACT` This is the most technically serious code-graph engine of the six: a real Cypher-queryable schema (46 node labels, 40 relationship types, `gitnexus-shared/src/graph/types.ts:10-227`), a genuine scope-resolution engine with C++ ADL, overload narrowing, per-language MRO strategies and framework-neutral DI edges, surgical incremental DB writeback, cross-repo contract bridging, and an optional PDG/taint layer. `FACT` **It is licensed PolyForm Noncommercial 1.0.0** (`LICENSE`, and `gitnexus/package.json:6` `"license": "PolyForm-Noncommercial-1.0.0"`) — commercial use of the OSS version requires a separate license from the vendor (`README.md:917`). For Specera, a commercial product, that single fact eliminates borrow and integrate: the code cannot be read-and-copied safely, and cannot be shipped or self-hosted commercially without a negotiated licence. `FACT` The OSS repo is explicitly a funnel: `README.md:39` links "Enterprise (SaaS & self-hosted)" at akonlabs.com and `README.md:915-930` gates PR review, auto-reindexing, multi-repo unified graph, and OCaml behind Enterprise. `INFERENCE` Read it as the reference design for what a correct code graph looks like — and as the strongest competitor in the graph layer — but treat every line as unusable IP.

## 2. Core architecture and unique mechanism

**Pipeline.** `FACT` 19 phases with declared deps, topologically sorted by Kahn's algorithm with cycle tracing, executed sequentially, all mutating one shared `KnowledgeGraph` (`ARCHITECTURE.md`, "Pipeline Phase DAG"; runner at `gitnexus/src/core/ingestion/pipeline-phases/runner.ts`):
`scan → structure → [springConfig, markdown, cobol] → parse → [routes, tools, orm] → crossFile → scopeResolution → [springAutoConfiguration, springAop] → pruneLocalSymbols → mro → springAopInheritance → di → communities → processes`. `--pdg` adds `taintSummaries` and `callSummaries` (21 total).

**Storage.** `FACT` Embedded **LadybugDB** (`@ladybugdb/core@^0.18.3`, `gitnexus/package.json:61`), described in `README.md:997` as "embedded graph database with vector support (**formerly KuzuDB**)". Database lives at `.gitnexus/` inside the repo; a registry at `~/.gitnexus/registry.json` maps repos for MCP discovery (`README.md:568`). Web UI runs the same pipeline against LadybugDB **WASM** in-browser (`README.md:91`). `INFERENCE` Kuzu is MIT-licensed, so the *storage* choice does not itself constrain self-hosting; the constraint is GitNexus's own PolyForm licence.

**Node schema — 46 labels.** `FACT` `gitnexus-shared/src/graph/types.ts:10-49`:
`Project, Package, Module, Folder, File, Class, Function, Method, Variable, Interface, Enum, Decorator, Import, Type, CodeElement, Community, Process, Struct, Macro, Typedef, Union, Namespace, Trait, Impl, TypeAlias, Const, Static, Property, Record, Delegate, Annotation, Constructor, Template, Section, Route, Tool, BasicBlock`.
`FACT` Each is a **separate LadybugDB node table** with its own DDL (`gitnexus/src/core/lbug/schema.ts:28-250`) — e.g. `File(id, name, filePath, content)`, `Function(id, name, filePath, startLine, endLine, isExported, content, description)`, `Route(id, name, filePath, responseKeys[], errorKeys[], middleware[], method, handlerSymbolId)`, `Property(… declaredType)`, `BasicBlock(id, filePath, startLine, endLine, text, callees, calleeIds)`. Most polyglot types share `CODE_ELEMENT_BASE` (`schema.ts:153`).

**Edge schema — 40 relationship types in ONE table.** `FACT` `gitnexus/src/core/lbug/schema.ts:1-9` documents the deliberate hybrid: separate node tables, one `CodeRelation` table carrying a `type` property, so agents can write `MATCH (f:Function)-[r:CodeRelation {type:'CALLS'}]->(g:Function)`. Types (`gitnexus-shared/src/graph/types.ts:107-227`):
- Structural: `CONTAINS`, `DEFINES`, `HAS_METHOD`, `HAS_PROPERTY`, `MEMBER_OF`
- Call/reference: `CALLS`, `USES`, `ACCESSES`, `IMPORTS`, `DECORATES`, `WRAPS`
- Type hierarchy: `INHERITS`, `EXTENDS`, `IMPLEMENTS`, `METHOD_OVERRIDES`, `METHOD_IMPLEMENTS`
- Framework/runtime: `INJECTS` (DI), `CONDITIONAL_ON` (Spring activation), `DECLARES` (metadata discovery), `ADVISED_BY` (AOP advice), `HANDLES_ROUTE`, `HANDLES_TOOL`, `FETCHES`, `QUERIES` (ORM), `ENTRY_POINT_OF`, `STEP_IN_PROCESS`, `BINDS_EVENT_HANDLER` / `EMITS_EVENT` (Vue)
- PDG/taint substrate (opt-in `--pdg`): `CFG`, `REACHING_DEF`, `CDG`, `TAINTED`, `SANITIZES`, `TAINT_PATH`, `CALL_SUMMARY`, `POST_DOMINATE`

`FACT` The type union is documented with unusual honesty about semantics: `CONDITIONAL_ON` "explicitly marks activation as unknown because runtime environment/classpath state may override source configuration"; `DECLARES` "deliberately does not claim that the target is active or registered at runtime"; `ADVISED_BY` "records statically visible advice only" (`types.ts:145-160`). `FACT` PDG-internal edges are deliberately excluded from `VALID_RELATION_TYPES` so they never leak into impact traversal (`types.ts:200-227`).

**Parser strategy.** `FACT` tree-sitter native bindings (CLI) / tree-sitter WASM (web). No LSP, no compiler frontend. `SupportedLanguages` enum (`gitnexus-shared/src/languages.ts:7-25`) is exactly 16: javascript, typescript, python, java, c, cpp, csharp, go, ruby, rust, php, kotlin, swift, dart, vue — **and cobol, annotated in the source as "Standalone regex processor — no tree-sitter, no LanguageProvider"** (`languages.ts:23-24`). `FACT` 10 grammars are npm deps (`gitnexus/package.json`: c-sharp, cpp, go, java, javascript, php, python, ruby, rust, typescript); Dart, Proto, Swift and Kotlin are **vendored** grammars cross-built by the project itself, and `GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1` disables all four at install with the README stating "those four languages won't be parsed" (`README.md`, install-problems block). `INFERENCE` Language support is therefore tiered: 10 first-class, 4 vendored-and-skippable, 1 regex-only (COBOL), 1 SFC wrapper (Vue).

**Call-graph resolution — the differentiator.** `FACT` This is not name matching. `gitnexus/src/core/ingestion/scope-resolution/` contains a `contract/`, `scope/`, `passes/`, `graph-bridge/`, `pipeline/` split with named passes: `callable-value-flow.ts`, `compound-receiver.ts`, `free-call-fallback.ts`, `imported-return-types.ts`, `mro.ts`, `overload-narrowing.ts`, `property-dispatch.ts`, `receiver-bound-calls.ts`. `FACT` Every unresolved site is *recorded with a typed reason*, not dropped silently — `ResolutionSuppressionReason` (`scope-resolution/resolution-outcome.ts:4-24`) enumerates: `adl-ordinary-lookup-blocked`, `conversion-rank-tied`, `inline-ns-ambiguous`, `member-lookup-ambiguous`, `selected-callable-deleted`, `overload-ambiguous`, `overload-ambiguous-normalization`, `free-call-instance-ownership`, `receiver-owned-but-unbound`, `receiver-unresolved`. `FACT` The `receiver-unresolved` doc comment states consumers use it "to report `impact()`/`context()` counts as a **lower bound** rather than as exact" — the tool knows and reports its own recall gap.
- `FACT` Interface/inheritance dispatch: the `mro` phase emits `METHOD_OVERRIDES` + `METHOD_IMPLEMENTS` using 5 language-specific strategies — "C++ leftmost-base, C#/Java class-over-interface, Python C3 linearization, Rust qualified syntax, default BFS" (`CHANGELOG.md` 1.4.0; `gitnexus-shared/src/mro-strategy.ts`).
- `FACT` DI containers: the `di` phase emits `INJECTS` from consumer classes or factory methods to provider classes, "framework-neutral DI resolution; per-language matchers registered in `di-extractors/`" (`ARCHITECTURE.md`, phase table). Its type doc says **"Ambiguous single injection is represented by multiple lower-confidence edges instead of a fabricated exact target"** (`types.ts:127-142`).
- `FACT` Name-based matching exists only as the last of three tiers: "3-tier resolver: exact FQN → scope-walk → **guarded fuzzy fallback that refuses ambiguous matches**" (`CHANGELOG.md` 1.4.0).

**Cross-repo.** `FACT` Real, not client-side merge: `gitnexus/src/core/group/` implements repo groups with a Contract Registry (`contracts.json`), a bridge graph in its own DB (`bridge-db.ts`), `cross-impact.ts` and `cross-trace.ts`. `trace` joins a home-repo segment to a target-repo segment across a single `ContractLink` (HTTP consumer→provider, joined on `Contract.symbolUid`), reported as a `CONTRACT_LINK` hop. `FACT` Depth is clamped: `MAX_SUPPORTED_CROSS_DEPTH` allows exactly one boundary crossing; deeper is reported in `notes[]`, and "full cross-program (SDG-like) data flow across the boundary remains deferred" (`ARCHITECTURE.md`).

**Incremental.** `FACT` Two independent mechanisms, both real:
1. *Parse cache* (`gitnexus/src/storage/parse-cache.ts:1-23`): chunk-level, content-addressed, key = `sha256(joined(filePath:contentHash, sorted))` over ~20 MB chunks. Its own header states **"The pipeline always parses every file (correctness invariant: cross-file resolution and downstream phases need full graph data). What this cache does is skip the tree-sitter worker dispatch when a chunk's contents haven't changed."** Cache version is composed with the npm package version so a grammar/extractor upgrade auto-invalidates.
2. *Surgical DB writeback* (`gitnexus/src/core/incremental/`): `diffFileHashes` against `meta.json.fileHashes`, then `computeEffectiveWriteSet` = changed ∪ importer-BFS ∪ a **1-hop boundary-crossing walk** to catch cases like a barrel re-export moving a symbol so an *unchanged* file's `CALLS` edge must re-target (`subgraph-extract.ts:22-48`). Above `INCREMENTAL_MAX_WRITE_FRACTION = 0.5` of files (and ≥ `INCREMENTAL_ESCALATION_MIN_FILES = 50`) it escalates to a full wipe-and-bulk-COPY (`escalation-gate.ts:20-30`). Eligibility is decided post-pipeline against actual output, requires a `.git` dir, matching schema fingerprint, and matching analysis-feature versions (`run-analyze.ts:1700-1721`).
`INFERENCE` So the answer to "diff or rebuild?" is: **all phases rebuild; tree-sitter work and DB rows are diffed.** On a one-file commit the graph is still fully recomputed in memory.

**Freshness.** `FACT` `gitnexus/src/mcp/staleness.ts` → `core/git-staleness.ts` compares the indexed `lastCommit` to current `HEAD` and surfaces hints to the agent; `detect_changes` MCP tool maps a git diff to affected symbols/processes. `FACT` Auto-reindexing is an Enterprise feature (`README.md:923`), i.e. the OSS tool tells you it is stale but does not fix itself.

## 3. Strongest capabilities

- `FACT` A real, declared, Cypher-addressable schema with per-type node tables (`gitnexus/src/core/lbug/schema.ts`) and a single `CodeRelation` table keyed by `type` — an LLM can write ad hoc Cypher without a schema translation layer, and the `cypher` MCP tool exposes exactly that.
- `FACT` Typed suppression reasons for unresolved call sites (`resolution-outcome.ts:4-24`) with an explicit contract that impact counts are a lower bound. No other repo of the six models its own recall.
- `FACT` Framework-aware edges that most graph tools omit entirely: `INJECTS`, `ADVISED_BY`, `CONDITIONAL_ON`, `DECLARES`, `HANDLES_ROUTE`, `HANDLES_TOOL`, `QUERIES`, `EMITS_EVENT`/`BINDS_EVENT_HANDLER`.
- `FACT` `shape_check` MCP tool: compares an API response shape against consumer property access to find mismatches — a contract-drift detector built on the graph, not on types.
- `FACT` Cross-repo trace/impact over an HTTP contract bridge (`src/core/group/cross-trace.ts`), with the boundary-crossing limit documented rather than hidden.
- `FACT` Optional intra-procedural PDG + taint (`--pdg`), read through `pdg_query` (CDG `mode: controls`, REACHING_DEF `mode: flows`) and `explain` (persisted source→sink findings).
- `FACT` An actual agent-outcome evaluation harness: `eval/` runs **SWE-bench** instances in Docker across 9 model configs and three modes (`baseline` / `native` / `native_augment`) to test whether graph tools raise resolve rate (`eval/README.md:1-20`, `eval/run_eval.py`, `eval/environments/gitnexus_docker.py`).
- `FACT` 840 `*.test.ts` files outside `node_modules`; the parse workers, scope-resolution passes, and the escalation gate are individually unit-tested (`escalation-gate.ts:12-16` explicitly says it was extracted to a pure module so an `&&`→`||` mutation cannot survive CI).
- `FACT` Supply-chain hygiene: images published only from `vX.Y.Z` tags with a version-match assertion, dual-registry same-digest publishing, and `cosign verify` instructions (`README.md:857-871`); OpenSSF Scorecard badge.

## 4. Critical weaknesses

- `FACT` **PolyForm Noncommercial 1.0.0.** `LICENSE` grants rights only for "permitted purposes" = noncommercial, personal, or use by charitable/educational/public-research/government organisations. Commercial use requires a separate licence (`README.md:917`). This is not a copyleft problem Specera can engineer around — it is a use prohibition.
- `FACT` **The graph is recomputed in full on every analyze.** `parse-cache.ts:4-7` states it plainly. The incrementality is in tree-sitter dispatch and DB rows, not in the 19 analysis phases.
- `FACT` **No accuracy benchmark of the graph itself.** `eval/` measures downstream *agent task resolve rate on SWE-bench*, not call-graph precision/recall. `INFERENCE` Combined with the `receiver-unresolved` "lower bound" admission, the tool's own resolution recall is unmeasured and self-declared incomplete.
- `FACT` **COBOL is regex-only** (`languages.ts:23`) yet appears as a supported language; Dart/Proto/Swift/Kotlin silently disappear if `GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1` or no prebuild matches the platform (`README.md`, install block).
- `FACT` **Cross-repo data flow is clamped to one hop** (`MAX_SUPPORTED_CROSS_DEPTH`) and PDG "data flow never crosses the repo boundary" (`ARCHITECTURE.md`). A 3-service call chain is not traceable end to end.
- `FACT` **Dynamic dependencies beyond the modelled frameworks are absent.** Spring, Vue, Prisma/Supabase, Next.js/Expo/PHP routes and MCP tools have dedicated phases; message queues, reflection, and generic config-driven wiring have no edge type. `INFERENCE` The coverage model is "one phase per framework", which does not generalise — every new framework is new code.
- `FACT` **Auto-reindex, PR review, and multi-repo unified graph are Enterprise-gated** (`README.md:919-925`), i.e. the OSS graph goes stale unless the user re-runs `analyze`.
- `FACT` Operational sharp edges are documented at length: npm 11 arborist crash, `npx` MCP startup exceeding Claude Code's ~30s `MCP_TIMEOUT`, `onnxruntime-node` postinstall fetching CUDA binaries from `api.nuget.org` while ignoring `HTTP_PROXY`/`HTTPS_PROXY` (issue #2370), 16 GiB max DB size, buffer-pool tuning env vars. `INFERENCE` This is a heavy native-dependency install for what is nominally an `npx` one-liner.
- `FACT` `@scarf/scarf@^1.4.0` is a production dependency (`gitnexus/package.json:61`) with no source references. `UNVERIFIED` whether install analytics actually fire — verifying would require reading `node_modules/@scarf/scarf` postinstall behaviour and the published tarball, which was not done here (no install was run).

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No requirement node label in `gitnexus-shared/src/graph/types.ts:10-49` |
| Jira/work tracking | No | No tracker integration in `gitnexus/src/` |
| Architecture/ADR | Partial | `Section` nodes + cross-links from `.md`/`.mdx` (`markdown` phase); `Community`/`Process` nodes synthesise subsystems and flows; Code Wiki generator (`src/core/wiki/`) |
| Implementation | Partial | MCP tools `query`, `context`, `cypher`, `trace`, `route_map`, `tool_map`; `rename` performs graph-assisted multi-file rename with `dry_run` — the only *write* action |
| PR review | Partial (OSS) / Yes (Enterprise) | `detect_changes` maps a git diff to affected symbols; `impact` gives blast radius with risk summary; automated PR blast-radius review is listed under Enterprise (`README.md:921`); `pr-swarm-review/` exists in-repo |
| Test generation | No | "end-to-end test generation" listed as **Upcoming** Enterprise (`README.md:928`) |
| Security/pentest | Partial | `--pdg` taint analysis, `explain` returns persisted source→sink findings, `SANITIZES`/`TAINTED`/`TAINT_PATH` edge types (`types.ts:190-198`) — intra-procedural, single-repo |
| Release | No | — |
| Monitoring/incidents | No | "auto regression forensics" is Upcoming Enterprise (`README.md:928`) |
| Maintenance/knowledge | Yes | `impact`, `api_impact`, `shape_check`, Code Wiki, `Process`/`Community` nodes, staleness hints |

## 6. Security, deployment, and license

- `FACT` **License: PolyForm Noncommercial 1.0.0** — `.spike/clones/GitNexus/LICENSE` (73 lines) and `gitnexus/package.json:6`. Permitted purposes are noncommercial only; charitable/educational/public-research/government use is permitted regardless of funding; patent grant included with a patent-defence termination clause; 32-day cure period on first violation. `INFERENCE` **Specera cannot borrow code, vendor, fork, or ship any part of this.** Reading it for competitive understanding is fine; copying design *ideas* is fine; copying implementation is not.
- `FACT` Deployment: local CLI + stdio MCP (`gitnexus mcp`), an HTTP bridge (`gitnexus serve`, Express on port 4747, with `express-rate-limit` and `cors`), and Docker images `ghcr.io/abhigyanpatwari/gitnexus` + `akonlabs/gitnexus` (`README.md:805-806`), cosign-verifiable.
- `FACT` Tenancy: none in OSS. Single-user local index at `.gitnexus/`, global registry at `~/.gitnexus/registry.json`. LadybugDB connections open lazily, evicted after 5 minutes idle, max 5 concurrent (`README.md:568`).
- `FACT` Privacy claim: `README.md:91` "Everything local, no network" for CLI; "Everything in-browser, no server" for web. `INFERENCE` Contradicted at install time by the `onnxruntime-node` NuGet fetch (`README.md`, proxy note) and by the presence of `@scarf/scarf`. The claim is about *analysis*, not *installation*.
- `FACT` LLM egress is opt-in and configurable (Azure OpenAI compat in `CHANGELOG.md` 1.5.3; embeddings run locally via onnxruntime).
- **Prompt-injection surface.** `FACT` The MCP tools return graph content (`content STRING` is stored on `File`, `Function`, `Class` node tables — `schema.ts:28-56`), i.e. attacker-controllable repo text flows into an agent's context. `FACT` One concrete mitigation is visible: "Wiki HTML viewer script injection — escape `</script>` in embedded JSON so LLM-generated markdown no longer breaks the viewer" (`CHANGELOG.md` 1.5.3). `UNVERIFIED` whether MCP tool output is sanitised or delimiter-wrapped before reaching the agent — verifying would need a read of `gitnexus/src/mcp/tools.ts` output formatting, not done here. There is a `SECURITY.md` and a `GUARDRAILS.md` in-repo.
- `FACT` The `cypher` MCP tool accepts ad hoc Cypher from a model; `gitnexus/src/core/lbug/cypher-escape.ts` and `query-params.ts` exist. `INFERENCE` Exposing raw Cypher to an LLM over untrusted repo content is a real injection-to-query path; the mitigation quality was not audited.

## 7. Ideas to adopt or avoid

### Adopt
- **Hybrid schema: node table per type, one relation table with a `type` column.** `gitnexus/src/core/lbug/schema.ts:1-9` states the reason — LLM-writable Cypher. Specera should copy this *shape decision* (it is a design pattern, not code): typed node tables give the model autocomplete-able labels; a single edge table means adding a relationship type is a data change, not a DDL migration.
- **Typed suppression reasons on every unresolved reference.** Specera's resolver should persist a row per dropped call site with a reason enum, and every impact/blast-radius API should return `exact | lower_bound` accordingly. This is the single most valuable idea in the repo: it converts silent recall loss into a measurable, queryable quantity.
- **"Ambiguous injection → multiple lower-confidence edges, never a fabricated exact target"** (`types.ts:131-134`). Adopt verbatim as a policy for all ambiguous resolution in Specera, not just DI.
- **Relationship types that carry an explicit runtime-uncertainty disclaimer.** `CONDITIONAL_ON` and `DECLARES` document that static presence ≠ runtime activation. Specera should make that a schema *column* (`static_only: bool` / `activation: unknown`) rather than prose, so queries can filter it.
- **The 1-hop boundary-crossing expansion in incremental writeback** (`subgraph-extract.ts:22-48`). The barrel-re-export case it describes — an unchanged file's edge must re-target because a third file changed — is the bug every naive "reindex changed files" implementation ships with. Specera must handle it on day one.
- **Escalation gate with a measured crossover** (`escalation-gate.ts`): above ~50% of files changed, stop doing surgery and rebuild. Cheap, and prevents the pathological slow path.
- **Content-addressed parse cache keyed by (content hash + tool version).** Same lesson as graphify: a parser upgrade must invalidate.
- **SWE-bench-style outcome eval with baseline / tools / auto-augmented arms** (`eval/configs/modes/`). Specera should measure the *delta the graph buys an agent*, not just graph statistics — but should additionally measure graph precision/recall, which GitNexus does not.
- **`shape_check`**: response shape vs consumer property access. A concrete, high-signal defect class Specera can detect from the graph with no LLM.

### Avoid
- **Copying any implementation.** PolyForm Noncommercial. Design patterns only.
- **One ingestion phase per framework.** Spring gets three phases, Vue gets two edge types, Prisma/Supabase get one. `INFERENCE` This scales linearly in maintenance forever; Specera should prefer a declarative framework-binding spec loaded as data.
- **Shipping a language in the enum that is regex-parsed** (`Cobol`). If Specera lists a language, the tier must be visible in the API response, not in a source comment.
- **Native-grammar vendoring with platform prebuilds.** Four grammars cross-built in CI, with a documented "no prebuild matches your platform → that language is unavailable" failure. WASM grammars avoid this entirely.
- **Whole-pipeline recomputation on every commit.** GitNexus is fast enough to get away with it at repo scale; a hosted multi-tenant product cannot.

## 8. Build, borrow, buy, integrate, or reject

**Reject (as code) / Study (as design).** PolyForm Noncommercial 1.0.0 forbids commercial use of the OSS software, so Specera can neither vendor, fork, integrate, nor self-host it without a commercial licence from Akon Labs — and given the vendor sells the same capability as Enterprise SaaS, a licence would be a buy-from-competitor decision, not a component decision. The correct action is to treat `gitnexus-shared/src/graph/types.ts` and `gitnexus/src/core/lbug/schema.ts` as the reference specification for what a code-graph schema must contain, reimplement independently, and use `eval/` as the template for how to prove the graph earns its keep. If Specera later wants the capability rather than the build, the honest option is **buy/partner** with Akon Labs.

## 9. Evidence

- Commit read: `9eaf2e6c` — `9eaf2e6c 2026-08-03 perf(mcp): cut the analyze-only language-provider closure out of MCP server startup (#2802) (#2806)`; package version `1.6.9` (`gitnexus/package.json:3`).
- Repo: https://github.com/abhigyanpatwari/GitNexus — 1,745 commits, first 2026-01-03, 1,628 in the last 6 months.
- Schema: `gitnexus-shared/src/graph/types.ts:10-49` (46 `NodeLabel`s), `:107-227` (40 `RelationshipType`s), `gitnexus/src/core/lbug/schema.ts:28-250` (LadybugDB DDL), `schema.ts:556` (`CREATE REL TABLE CodeRelation`), `schema.ts:589` (embedding table).
- Resolution: `gitnexus/src/core/ingestion/scope-resolution/resolution-outcome.ts:4-24`, `.../passes/{free-call-fallback,overload-narrowing,mro,receiver-bound-calls,property-dispatch,compound-receiver,callable-value-flow,imported-return-types}.ts`, `gitnexus-shared/src/mro-strategy.ts`.
- Incremental: `gitnexus/src/storage/parse-cache.ts:1-23`, `gitnexus/src/core/incremental/{subgraph-extract,escalation-gate,shadow-candidates}.ts`, `gitnexus/src/core/run-analyze.ts:1700-1721`.
- Cross-repo: `gitnexus/src/core/group/{service,sync,bridge-db,cross-impact,cross-trace}.ts`; `ARCHITECTURE.md` group-mode section.
- Languages: `gitnexus-shared/src/languages.ts:7-25`; grammar deps in `gitnexus/package.json:83-93`; vendored-grammar caveats in `README.md` install block.
- Eval: `eval/README.md`, `eval/run_eval.py`, `eval/configs/models/*.yaml` (9), `eval/configs/modes/{baseline,native,native_augment}.yaml`, `eval/environments/gitnexus_docker.py`.
- License: `.spike/clones/GitNexus/LICENSE` (PolyForm Noncommercial 1.0.0, 73 lines) read in full; `gitnexus/package.json:6`.
- Docs read: `README.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `LICENSE`, `gitnexus/package.json`, `eval/README.md`.
- Commands run (read-only; no install, build, or test execution): `git rev-parse --short HEAD`, `git log`, `find`, `grep`, `sed`, `head`, `wc`.
- Test surface measured: `find . -name '*.test.ts' -not -path '*/node_modules/*' | wc -l` → 840.
