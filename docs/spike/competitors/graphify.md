# graphify (Graphify-Labs/graphify, OSS CLI)

A Python CLI that tree-sitter-parses a repo (plus docs/PDF/media via an LLM pass) into a single NetworkX graph serialised to `graph.json`, then answers queries by traversing it — no embeddings, no database required.

## 1. Verdict

`FACT` This is the most mature open-source code-graph builder of the six reviewed: 281 Python modules, 176 test files, 3,442 test functions, 1,342 commits since 2026-04-03 (`git -C .spike/clones/graphify log --oneline | wc -l`). Its single best trait is that the *code* half of the graph is built with **zero LLM calls** and every edge carries a provenance tag (`EXTRACTED` / `INFERRED` / `AMBIGUOUS`, `graphify/validate.py:5`), so a consumer can filter to only edges that were literally read from source. What kills it as a Specera component: the graph is a **file artifact, not a database** — `graph.json` + NetworkX in memory — so there is no concurrent multi-user query path, no transactional incremental write, and no cross-repo joins beyond a hand-rolled merge in `graphify/global_graph.py`. `FACT` The OSS repo is an explicit loss-leader: `README.md:26` and `README.md:803-807` push "graphify Enterprise"/`app.graphify.com` waitlist, and the repo carries a YC S26 badge (`README.md:22`). `INFERENCE` (from those README lines plus the absence of any always-on daemon in the OSS tree — only `graphify/watch.py`, a local file watcher) the continuously-updating multi-source graph is deliberately withheld from OSS.

## 2. Core architecture and unique mechanism

`FACT` Pipeline is seven pure functions communicating via dicts and `nx.Graph` (`ARCHITECTURE.md:9-31`):
`detect() → extract() → build_graph() → cluster() → analyze() → report() → export()`.

**Storage.** `FACT` Primary store is `graphify-out/graph.json` (NetworkX node-link JSON) plus `graph.html` and `GRAPH_REPORT.md`. Neo4j and FalkorDB are *export targets only*, not the query path: `graphify/exporters/graphdb.py:8` `push_to_neo4j()` MERGEs nodes with a per-node label derived from the node's own `label` string sanitised by `_safe_label()` (`graphify/exporters/graphdb.py:36`) and relationship types uppercased by `_safe_rel()`. `INFERENCE` This means there is no fixed Neo4j label schema at all — labels are whatever the source identifiers happened to be — so the Neo4j export is unusable as a stable schema to build on.

**Node schema.** `FACT` Only four fields are required (`graphify/validate.py:6`): `id`, `label`, `file_type`, `source_file`. `file_type` is a closed 6-value vocabulary (`graphify/validate.py:4`): `code`, `document`, `paper`, `image`, `rationale`, `concept`. There is **no node-kind taxonomy** — a function, a class, a file and a module are all `file_type: "code"`, distinguished only by which edges point at them (`contains`, `method`, `defines`).

**Edge schema.** `FACT` Required fields (`graphify/validate.py:7`): `source`, `target`, `relation`, `confidence`, `source_file`. `confidence` is validated against exactly `{EXTRACTED, INFERRED, AMBIGUOUS}` (`graphify/validate.py:5`). `relation` is **not validated against any vocabulary** — it is a free string. The relation values actually emitted by the extractors, counted over `graphify/` (`grep -rohE 'add_edge\([^,]+, *[^,]+, *"[a-z_]+"'`), 21 distinct:

`references` (79 sites), `contains` (43), `defines` (21), `method` (16), `calls` (16), `imports` (13), `inherits` (10), `imports_from` (9), `implements` (5), `extends` (5), `uses` (3), `reads_from` (3), `navigates` (3), `triggers` (2), `embeds` (2), `requires` (1), `mixes_in` (1), `instantiates` (1), `exports` (1), `configures` (1), `accesses` (1).

Plus, emitted via dict literals rather than the helper: `indirect_call`, `re_exports`, `crate_depends_on`, `depends_on`, `rationale_for`, `cites`, `requires_env`, `bound_to`, `binds_method`, `listened_by`, `uses_component`, `uses_static_prop`, `references_constant`, `includes`. `INFERENCE` The vocabulary is grown ad hoc per language feature; because `validate.py` never checks it, a typo in a new extractor produces a silently unqueryable edge type.

**Parser strategy.** `FACT` tree-sitter only, no LSP, no compiler frontend. 25 grammars are hard dependencies (`pyproject.toml:18-43`: python, javascript, typescript, go, rust, java, groovy, c, cpp, ruby, c-sharp, kotlin, scala, php, swift, lua, zig, powershell, elixir, objc, julia, verilog, fortran, bash, json) plus 4 optional extras (`pyproject.toml:77-87`: sql, pascal, dm, hcl/terraform). `FACT` `CODE_EXTENSIONS` in `graphify/detect.py:31` lists ~90 extensions — considerably more than there are grammars — and the code itself admits the gap: `graphify/extract.py` prints *"file(s) are classified as code but graphify has no AST extractor for their language, so they contributed nothing to the graph"* and names `.r/.R` explicitly (issue #1689 comment block). A second warning path covers extensions whose extractor exists but whose optional grammar is not installed, which "silently contributed nothing" (issue #1745). `INFERENCE` The README's "~40 languages" (`README.md`, capability table) counts extensions, not resolving extractors; the honest number of grammar-backed languages is 25 installed-by-default plus 4 opt-in.

**Call resolution.** `FACT` Two-pass: per-file structural extraction, then a cross-file pass (`graphify/extract.py:4600-4604`). Cross-file member-call resolution is **name-keyed with an ambiguity bail-out**, not type-driven (`graphify/extract.py:2375-2428`):
- Capitalised receiver → looked up in `class_def_nids` by normalised name key; `if len(class_nids) != 1: continue` — the "god-node guard". A method call on a class name that appears twice in the corpus produces **no edge at all**.
- Lowercase receiver → matched against modules imported into the caller's *file*, by file-stem key or import alias; again bails if not exactly one.
- `_key()` is `re.sub(r"[^a-zA-Z0-9]+", "", label).lower()` — so `user_repo` and `UserRepo` collide by design.

`FACT` One DI-shaped special case exists: `_resolve_typescript_member_calls` (`graphify/extract.py:2434-2445`) reads TypeScript constructor parameter-property modifiers (`private repo: IUserRepository`) into a per-file type table and resolves `this.repo.findById()` through it. `FACT` That is the only interface/injection-aware path; the docstring states plainly that without it "`this.repo.findById()` drops out in the shared cross-file pass because bare `findById` collides across the corpus (god-node guard)". `INFERENCE` For every other language, calls through an interface, a base-class reference, or a container-resolved dependency are dropped rather than mis-resolved — a false-negative bias, not a false-positive one. That is the safer failure mode but it means the call graph is systematically incomplete on any codebase using polymorphism.

`FACT` Cross-language false edges are actively suppressed: `_EDGE_LANG_FAMILY` (`graphify/build.py:61-75`) groups extensions into interop families (`py`, `js`, `go`, `rs`, `jvm`, `c`, `rb`, `php`, `cs`, `swift`, `lua`) and drops edges crossing families — the comment cites real bugs where Python `import time` bound to a `time.ts` (#1749).

**SCIP.** `FACT` `graphify/scip_ingest.py` exists but its own docstring says: *"NOT a full SCIP protobuf implementation — this is a skeleton… Not wired to the CLI in this phase"* and that the shape it consumes *"diverges from the official SCIP protobuf"* and matches *"LLM-generated SCIP-style JSON"*. `INFERENCE` Precise LSIF/SCIP-grade resolution is aspirational here, not delivered.

**Query path.** `FACT` `graphify query|path|explain` run graph algorithms over the loaded `graph.json`; `graphify/serve.py:1348-1457` exposes MCP tools `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`, `list_prs`, `get_pr_impact`, `triage_prs`. Communities come from Leiden clustering (`graphify/cluster.py`, `graspologic` dep).

## 3. Strongest capabilities

- `FACT` Per-edge provenance as a first-class, validated field (`graphify/validate.py:5`) — the only repo of the six that lets a consumer distinguish "the source says this" from "we guessed this".
- `FACT` Deterministic, zero-token code indexing: `BENCHMARKS.md` "Graph construction costs zero LLM credits"; only the docs/media semantic pass calls a model.
- `FACT` Content-hash incremental extraction with a version-namespaced AST cache (`graphify/cache.py:18-32`) — cache entries live under `cache/ast/v{package_version}/` and sibling version dirs are swept, so an extractor bug-fix release invalidates stale results instead of serving them.
- `FACT` `detect_incremental()` (`graphify/detect.py:1802-1847`) does a genuine diff: stat/mtime fast path, MD5 slow path, separate `ast_hash` and `semantic_hash` so an AST-only `graphify update` does not mark a file semantically done.
- `FACT` Blast-radius traversal is a shipped feature: `graphify/affected.py:12-26` walks a fixed relation set (`calls, indirect_call, references, imports, imports_from, re_exports, inherits, extends, implements, uses, mixes_in, embeds, requires`) and `AffectedHit` records the *call site* file+line (`via_file`, `via_location`), not the definition line.
- `FACT` PR-aware surface: `graphify/prs.py` maps open PRs to graph communities, including `--conflicts` ("PRs sharing graph communities (merge-order risk)").
- `FACT` Documented prompt-injection defence for the LLM pass: files wrapped in hash-stamped `<untrusted_source path=… sha256=…>` blocks with sentinel defanging (`SECURITY.md`, threat table); the doc is candid that this "does not make injection impossible".

## 4. Critical weaknesses

- `FACT` **No node-type taxonomy.** `file_type` has 6 values and none of them is "function" or "class" (`graphify/validate.py:4`). Any consumer wanting "all public HTTP handlers" must reverse-engineer it from edge patterns.
- `FACT` **Edge `relation` is unvalidated free text** (`graphify/validate.py:7` requires the key, never checks the value), across ~35 distinct values emitted from at least three different code paths.
- `FACT` **Call graph is name-keyed with a case- and separator-insensitive normaliser** (`_key()` at `graphify/extract.py:2400`), and bails to *no edge* whenever a name is ambiguous. Interface and base-class dispatch is unresolved outside the single TypeScript constructor-injection path.
- `FACT` **Code-quality evaluation is n=6.** `BENCHMARKS.md`: "giving a fixed coding agent one graphify tool lifts key-fact coverage across the graded question set (**n=6**) from 70.8% … to 82.0%". The headline benchmarks (LOCOMO n=300, LongMemEval-S n=50) measure conversational *memory*, not code-graph correctness. `INFERENCE` There is **no precision/recall measurement of the call graph itself anywhere in the repo** — the temporal ERPNext table (`BENCHMARKS.md`) reports node/edge *counts* over 689 checkpoints, which measures stability, not accuracy.
- `FACT` Silent-blindness classes are acknowledged in-source with issue numbers: files that parse to zero nodes (#1666), extensions classified as code with no extractor (#1689), and extractors disabled by a missing optional grammar (#1745). All three degrade to warnings on stderr while the run reports success.
- `FACT` **Cross-repo is a client-side merge**: `graphify/global_graph.py:10-12` keeps `~/.graphify/global-graph.json` + a manifest of tracked repos. `INFERENCE` There is no service boundary model — an HTTP call from repo A to repo B is not an edge type in the vocabulary; `reads_from`/`triggers`/`listened_by` exist but are emitted from single-file patterns, not resolved across services.
- `FACT` Dynamic wiring is not modelled. `graphify/reflect.py` is *not* runtime reflection — it aggregates saved Q&A outcomes into a `LESSONS.md`. There is no config-driven-wiring, message-queue, or DI-container resolver outside the TS constructor case.
- `INFERENCE` NetworkX-in-memory + a single JSON artifact caps corpus size at whatever fits in one process's RAM; the largest published graph is 22,620 nodes / 48,710 edges (`BENCHMARKS.md`, ERPNext 2026-06-24), which is small for a 1M-LOC repo and suggests aggressive node collapsing.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No requirement node type; `file_type` vocabulary is `graphify/validate.py:4` |
| Jira/work tracking | No | No issue-tracker integration in `graphify/` |
| Architecture/ADR | Partial | `README.md` capability table: "`# NOTE:` / `# WHY:` comments and ADR/RFC citations become first-class nodes"; edges `rationale_for`, `cites` |
| Implementation | Partial | Read-only graph + MCP tools (`graphify/serve.py:1348-1457`); does not write code |
| PR review | Partial | `graphify/prs.py` — PR dashboard, graph-impact per PR, `--conflicts` community overlap, `--triage` LLM ranking; MCP `get_pr_impact`/`triage_prs` |
| Test generation | No | No test-generation code path |
| Security/pentest | No | `graphify/security.py` hardens graphify itself; it does not analyse the target repo |
| Release | No | — |
| Monitoring/incidents | No | — |
| Maintenance/knowledge | Yes | `graphify/affected.py` blast radius, `graphify/reflect.py` lessons artifact, Obsidian/wiki export (`graphify/export.py`) |

## 6. Security, deployment, and license

- `FACT` **License: Apache-2.0** (`.spike/clones/graphify/LICENSE`, 202 lines, standard ASL 2.0 text). `NOTICE` states the project was relicensed from MIT and that pre-relicensing contributions remain available under MIT (`LICENSE-MIT`, © 2026 Safi Shamsi). `INFERENCE` Apache-2.0 is permissive with a patent grant; safe to vendor or fork for a commercial product, requires NOTICE propagation.
- `FACT` Local-first by default. `SECURITY.md`: "makes no network calls during graph analysis - only during `ingest` (explicit URL fetch by the user)". A grep for `requests.post`/`urlopen`/`httpx.post` outside `security.py` returned nothing — no telemetry.
- `FACT` No auth model, no tenancy, no server: output is files under `graphify-out/`; the MCP server is stdio and path-restricted to `graphify-out/` via `validate_graph_path()` (`SECURITY.md` threat table).
- `FACT` Egress surface is `ingest` (SSRF-guarded: http/https only, private/loopback/link-local and cloud-metadata blocked, redirects re-validated, 50 MB cap) and the optional semantic pass to a configured LLM backend (openai/anthropic/boto3 are optional deps, `pyproject.toml:88`).
- `FACT` Prompt-injection surface is explicit and mitigated at two points: source content into the semantic-pass LLM (`<untrusted_source>` wrapping + sentinel defanging), and node labels into MCP text output (`sanitize_label()`).
- `FACT` Commercial counterpart: `README.md:803` "graphify Enterprise … the always-on layer built on top of graphify", waitlist at graphify.com. Not evaluated here.

## 7. Ideas to adopt or avoid

### Adopt
- **Per-edge provenance enum, validated at ingest.** Specera should carry `EXTRACTED | INFERRED | AMBIGUOUS` (or equivalent) as a required, schema-checked column on every edge, exactly as `graphify/validate.py:5` does — but extend the same discipline to `relation`, which graphify leaves unchecked. Concretely: a closed enum table for edge type, FK-enforced.
- **The god-node guard as a policy, made explicit.** `graphify/extract.py:2405` (`if len(class_nids) != 1: continue`) is a good default — never emit an edge you cannot pin to one definition. Specera should keep the bail-out but *record the drop* as an `AMBIGUOUS` edge with the candidate set, so blast-radius queries can widen deliberately instead of silently missing.
- **Version-namespaced parse cache.** `graphify/cache.py:18-32` keys the AST cache by extractor package version and sweeps other versions. Specera's index must do this or a parser bugfix will serve pre-fix results forever.
- **Cross-language edge suppression by interop family.** `graphify/build.py:61-75`. Specera should ship the same table on day one; the referenced bugs (#1749, #1547) are the exact failure a naive name index produces.
- **Call-site location on traversal results.** `AffectedHit.via_file` / `via_location` (`graphify/affected.py:37-40`) returns the *edge* site, not the node definition. Any impact-analysis API Specera exposes should do the same — a reviewer needs the line that calls, not the line that defines.
- **PR-to-subsystem conflict detection.** `graphify prs --conflicts` (PRs sharing graph communities = merge-order risk) is a cheap, genuinely novel SDLC hook Specera can reimplement over its own graph.

### Avoid
- **A single JSON artifact as the store.** No concurrency, no partial write, no query planner, whole-graph load per query.
- **Free-text edge relations.** ~35 undeclared values with no central registry.
- **Deriving Neo4j labels from source identifiers** (`graphify/exporters/graphdb.py:36`) — produces an unbounded label space and an unqueryable database.
- **Claiming language coverage by file extension.** `CODE_EXTENSIONS` (~90) vs grammars (25+4) vs the in-code "no AST extractor" warning is a credibility gap Specera should not reproduce; publish a table of *resolving* vs *tokenised* vs *ignored*.
- **Shipping without a call-graph accuracy benchmark.** n=6 graded questions is not an evaluation.

## 8. Build, borrow, buy, integrate, or reject

**Borrow.** Apache-2.0 makes the extractor logic, the interop-family table, the incremental-hash design, and the provenance enum directly reusable — copy the ideas and the specific fixture-driven bug fixes, not the storage layer. Specera cannot integrate graphify as its graph engine because `graph.json`/NetworkX cannot serve concurrent queries or cross-repo joins, and the schema (6 file types, unvalidated relations, no node kinds) is too weak to build a product surface on. The one thing worth reading line-by-line before writing Specera's own resolver is `graphify/extract.py:2375-2470` plus `graphify/build.py:55-80` — several hundred real-world resolution bugs are encoded there.

## 9. Evidence

- Commit read: `00efd6e` — `00efd6e 2026-08-01 fix(ruby): resolve compact/nested mixin targets, prevent phantom concern hub (#2302)`
- Repo: https://github.com/Graphify-Labs/graphify — 1,342 commits, first 2026-04-03, all 1,342 in the last 6 months (very high velocity, short history).
- Key files: `graphify/validate.py` (schema), `graphify/extract.py` (~264 KB, dispatch + cross-file resolution), `graphify/extractors/engine.py` (~257 KB), `graphify/extractors/resolution.py` (~115 KB, JS/TS module resolution incl. tsconfig paths), `graphify/build.py` (graph assembly + interop families), `graphify/detect.py` (file selection, `CODE_EXTENSIONS`, `detect_incremental`), `graphify/cache.py` (versioned AST cache), `graphify/affected.py` (blast radius), `graphify/prs.py`, `graphify/serve.py` (MCP), `graphify/exporters/graphdb.py` (Neo4j/FalkorDB export), `graphify/scip_ingest.py` (stub), `graphify/global_graph.py` (`~/.graphify/global-graph.json`).
- Docs read: `README.md`, `ARCHITECTURE.md`, `BENCHMARKS.md`, `SECURITY.md`, `LICENSE`, `LICENSE-MIT`, `NOTICE`, `pyproject.toml`.
- Commands run (read-only; no install, build, or test execution): `git rev-parse --short HEAD`, `git log`, `find`, `grep`, `sed`, and one `python3` regex scan over `extract.py`.
- Test surface measured: `find tests -name 'test_*.py' | wc -l` → 176; `grep -rh "^def test_\|^    def test_" tests/ | wc -l` → 3,442. Parser and builder are both covered (`tests/test_extract.py` 127 KB, `tests/test_languages.py` 122 KB, `tests/test_build.py` 67 KB, `tests/test_symbol_resolution.py`, `tests/test_js_import_resolution.py`).
