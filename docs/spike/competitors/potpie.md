# Potpie (potpie-ai/potpie, OSS CLI + daemon)

A Python CLI + local daemon that builds a bitemporal *SDLC* context graph — services, environments, datastores, decisions, bug patterns, people, activities — from GitHub/Linear/Jira/Confluence events plus a deliberately shallow tree-sitter code graph, reconciled into FalkorDB by an LLM agent and read back through a `resolve`/`search`/`record` surface for coding agents.

## 1. Verdict

`FACT` Potpie is **not a code-graph competitor any more**. Its HEAD commit `b5a67742 "Remove legacy platform code (#1034)"` deleted 629 files / 144,060 lines including the entire Neo4j-backed code-graph platform (`git show --stat b5a67742`), and what remains as a code graph is a small Rust crate emitting exactly four node types and two edge types. `FACT` What it *is* now is the closest thing in this set to **Specera's own thesis** — an ontology of 24 SDLC entity types, 26 predicates, and 15 agent-writable record types, with per-entity freshness TTLs, source-of-truth classes, and evidence strengths (`potpie/context-core/src/potpie_context_core/ontology.py`). That ontology is Apache-2.0 and is the single most directly reusable artifact found across all six repos. `FACT` What kills it as a component: the graph is written by an LLM reconciliation agent (`adapters/outbound/reconciliation/pydantic_deep_agent.py`), so graph content is model output, not derived truth; and the code layer resolves references by **bare name with a cross-file fan-out fallback** (`potpie/parsing/src/tag_extract.rs:110-152`), which is the worst call-graph correctness of the six.

## 2. Core architecture and unique mechanism

**Two graphs, glued at one node type.**

*Code graph (Rust, shallow).* `FACT` `potpie/parsing/` is a `pyo3` crate `parsing_rs` with 16 tree-sitter grammars (`Cargo.toml`: python, rust, javascript, typescript, go, java, c, cpp, ruby, php, c-sharp, elixir, ocaml, elisp, elm, ql). `FACT` Its entire schema, per `potpie/parsing/README.md:32-41`: node types `FILE`, `CLASS`, `INTERFACE`, `FUNCTION`; relationship types `CONTAINS` (FILE → CLASS/FUNCTION) and `REFERENCES` (FUNCTION → FUNCTION/CLASS). No imports, no inheritance, no calls-vs-uses distinction. `FACT` It runs inside a **Daytona sandbox** via `potpie/sandbox/sandbox/parser_runner/runner.py`, not in-process.

*Context graph (Python, the real product).* `FACT` `potpie/context-core/src/potpie_context_core/ontology.py` is a single declarative catalog of three tables — `ENTITY_TYPES` (line 288), `EDGE_TYPES` (line 694), `RECORD_TYPES` (line 1524) — from which the canonical writer, structural reader, reconciliation validator, graph-quality policy, and agent context port all derive their behaviour, with import-time coherence invariants (`potpie_context_core.coherence`) that fail startup if any two views disagree.

**Entity types — 24** (`ontology.py:288`):
`Repository, Service, Environment, DataStore, Cluster, Dependency, APIContract, Adapter, ConfigVariable, DeploymentTarget, CodeAsset, Feature, Team, Person, Activity, Period, Preference, Policy, BugPattern, Fix, Decision, Document, Observation, QualityIssue`.
`FACT` `CodeAsset` is *one* label covering "file, directory, module, class, function, symbol, or generated-code unit" (`ontology.py:441-446`) — the entire code world collapses to a single anchor type. `FACT` Five entities are flagged `scope=True` (`Repository`/`Service`/`Environment`/`DataStore`/`Cluster`) and act as endpoints for cross-cutting edges via a `@Scope` wildcard rather than each edge enumerating them (`ontology.py:44-48`, `:104`).

**Edge types — 26** (`ontology.py:694`), grouped by `category`:
- topology: `DEFINED_IN, DEPLOYED_TO, DEPENDS_ON, USES, USES_ADAPTER, CONFIGURES, DEPLOYED_WITH, EXPOSES, HOSTED_ON, PROVIDES, IMPLEMENTED_IN`
- ownership/people: `OWNED_BY, MEMBER_OF, TOUCHED, PERFORMED, AUTHORED`
- timeline: `IN_PERIOD, MENTIONS`
- memory: `POLICY_APPLIES_TO, REPRODUCES, RESOLVED, ATTEMPTED_FIX_FAILED, VERIFIED, DECIDED, AFFECTS`
- generic: `RELATED_TO`
Plus one system edge, `SUPERSEDES` (`ontology.py:958`).

`FACT` Every edge type is a full spec, not a string (`EdgeTypeSpec`, `ontology.py:176-216`): `allowed_pairs` (typed endpoint constraints, checked by `allows()`), `required_properties`, `lifecycle_carrier` (does it carry `proposed/planned/in_progress/completed/deprecated/decommissioned/unknown`), `predicate_family`, `exclusive_family`, `singleton`, and `source_inferred_labels`/`target_inferred_labels` for classifier-driven endpoint typing. `FACT` `singleton: True` means `(subject, predicate)` admits one live object at a time and the canonical writer **auto-stamps `invalid_at` on the prior live claim** — bitemporal supersession built into the schema (`ontology.py:200-207`).

**Claim model.** `FACT` Predicates ride on `:RELATES_TO` claims rather than being raw edges (`ontology.py:9-11`). Every claim carries a source-of-truth class from `{authoritative_external_truth, authoritative_code_truth, canonicalized_memory, soft_inference}` and an evidence strength from `{deterministic, attested, inferred, hypothesized}`, defaulting to `inferred` (`ontology.py:88-93`). `FACT` Each entity type declares a `freshness_ttl_hours` (e.g. `WEEK` for `Repository`/`Service`/`Environment`/`DataStore`), so staleness is a property of the *ontology*, not of the indexer.

**Write path.** `FACT` `graph propose → graph commit --verify` is the canonical write door; `graph mutate` is a legacy wrapper (`docs/context-graph/architecture.md:17-21`). `FACT` Ingestion is a **single LLM agent** (`pydantic_deep_agent.py:1-18`) that receives a batch of `ContextEvent`s and runs to completion against read-only graph lookups, a fat `apply_graph_mutations` tool, event-completion control, and a terminal `finish_batch` tool, with progress checkpointed after every tool call so a crashed worker can resume.

**Storage.** `FACT` A swappable `GraphBackend` port with six implementations (`adapters/outbound/graph/backends/`): `in_memory_backend.py` (the conformance reference — "no durability, no real embeddings, traversal is naive… but the *contract* is complete"), `embedded_backend.py`, `falkordb_backend.py`, `neo4j_backend.py`, `stub_backend.py`, `_unimplemented.py`. `FACT` Default is **falkordb_lite** in daemon host mode (`docs/context-graph/architecture.md`, composition-root diagram); deps are `falkordb>=1.6.1` and `falkordblite>=0.10.0` for "hostless embedded connection" (`potpie/context-engine/pyproject.toml:38-42`); Neo4j is an optional extra (`:48-49`). Cypher generation lives in `adapters/outbound/graph/cypher.py`.

**Versioning.** `FACT` `GRAPH_CONTRACT_VERSION="v1.5"`, `ONTOLOGY_VERSION="2026-06-graph"`, `GRAPH_WORKBENCH_CONTRACT_VERSION="v2"` — the ontology is an explicitly versioned contract (`docs/context-graph/architecture.md:14-18`).

## 3. Strongest capabilities

- `FACT` A **spec-driven ontology where adding an entity/predicate/record is one table row** and every consumer is a view over it, guarded by import-time coherence invariants (`ontology.py:22-32`). This is the correct architecture for a schema that must evolve.
- `FACT` Typed endpoint constraints per edge (`allowed_pairs` + `allows()`, `ontology.py:179`, `:214`) — the graph cannot accept a `DEPLOYED_TO` from a `Person`.
- `FACT` Bitemporal supersession as a schema flag (`singleton` → auto `invalid_at`, `ontology.py:200-207`) plus a `SUPERSEDES` system edge and a 7-state `LifecycleStatus` enum (`ontology.py:69-77`).
- `FACT` Per-entity `freshness_ttl_hours` and a four-level `source_of_truth` taxonomy — the only repo of the six where "how do I know this is stale / how much do I trust it" is modelled in the schema rather than inferred by the caller.
- `FACT` Genuine SDLC ingest: GitHub (repos, PRs, issues, reviews, source history), Linear (teams, issues, projects, documents), Jira (projects, issues, status, changelog), Confluence (spaces, pages, runbooks, decisions) (`README.md`, Integrations table; `potpie/integrations/`).
- `FACT` A graph-*quality* benchmark harness that scores retrieval against weighted assertions, runnable against all five real backends so an ontology/reader/storage change yields a comparable delta (`potpie/context-engine/scripts/BENCHMARK.md`, `docs/context-graph/bench-plan.md:11-16`, `src/potpie_context_engine/benchmarks/`). Scenarios include `v2_negative_space_missing_runbook` ("honest gap declaration when data is missing") and `v2_conflict_surfacing` (`response.conflicts` populated when the graph contradicts itself).
- `FACT` The reconciliation agent checkpoints after every tool call for crash-resume (`pydantic_deep_agent.py:16-18`).
- `FACT` Hexagonal architecture with two explicitly separated composition roots and the doc calling out that conflating them "is the most common architecture error" (`docs/context-graph/architecture.md`).

## 4. Critical weaknesses

- `FACT` **The code graph resolves references by bare name and fans out.** `potpie/parsing/src/tag_extract.rs:110-152`: the lookup key is `ident.split('.').last()`, so `repo.save()`, `db.save()` and `self.save()` all become `save`; all definitions with that name are candidates; same-file targets are preferred, and **when there is no same-file target, an edge is emitted to every cross-file definition of that name** (`let targets_to_use = if !same_file_targets.is_empty() { same_file_targets } else { cross_file_targets }` — note the plural). A repo with N definitions of `handle` produces N false `REFERENCES` edges per unresolved call site.
- `FACT` **The dedup key treats a reverse edge as a duplicate.** `tag_extract.rs:167-181` skips emission if either `(src,tgt,"REFERENCES")` **or** `(tgt,src,"REFERENCES")` is already seen. `INFERENCE` In a mutually-recursive or bidirectional-reference pair, one real direction is silently dropped — the relation is stored directed but populated as if undirected.
- `FACT` **`is_valid_reference_direction` is a four-line heuristic** (`tag_extract.rs:517-531`) whose first clause is `source_id.contains("Impl")` — a substring test on the node id. `INFERENCE` Rust `impl`-block handling is done by string sniffing, not by AST context.
- `FACT` **Graph content is LLM-authored.** The reconciliation agent decides what entities and edges exist (`pydantic_deep_agent.py`). `INFERENCE` Combined with `DEFAULT_EVIDENCE_STRENGTH = "inferred"` (`ontology.py:92`), the default trust level of a Potpie fact is "a model asserted it", which is a different product from a derived-truth graph.
- `FACT` **Incremental reindex is not addressed for code.** `extract_graph(repo_dir)` walks the whole repo and rebuilds (`tag_extract.rs:68-73`); there is no hash cache, no changed-file path. Context-graph freshness is handled instead by event ingestion + per-entity TTL, which is a different mechanism for a different data type.
- `FACT` **Cross-service edges are asserted, not derived.** `DEPENDS_ON` ("a service depends on / calls another service") is an ontology row with `source_inferred=("Service",)` — there is no static analysis that discovers an HTTP call between two services; it arrives via the LLM reconciler or an integration.
- `FACT` **Named roadmap gaps in the shipped tree**: the managed backend "raises `CapabilityNotImplemented`" and the external Event Ledger clients (`adapters/outbound/ledger/{managed,self_hosted}_client.py`) "are TODO stubs" (`docs/context-graph/bench-plan.md:17-24`).
- `FACT` **No accuracy evaluation of the code graph exists.** All benchmarking (`benchmarks/`, `BENCHMARK.md`) targets context retrieval scoring, not parse or reference correctness. `tests/` for the Rust crate are shape assertions (`tag_extract.rs:648`, `:700`, `:736` — "expected two CONTAINS edges and one REFERENCES edge"), not precision/recall.
- `FACT` Parsing runs in a **Daytona** cloud sandbox provider (`potpie/sandbox/pyproject.toml:13`, `sandbox/adapters/outbound/daytona/provider.py`, 63 KB). `INFERENCE` For a "local-first" CLI, routing source code through a third-party sandbox provider is a data-residency decision most enterprises will need to approve.
- `FACT` The repo's velocity dropped: 752 commits total, only 195 in the last six months, first commit 2024-08-12 — and one of those recent commits deleted the previous product. `INFERENCE` Potpie has pivoted twice; the current shape is young.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | Partial | `Feature` entity + `feature_note` record type; Linear/Jira/Confluence ingestion of projects, issues, documents (`README.md` Integrations) |
| Jira/work tracking | Yes | Linear, Jira, Confluence integrations; `Activity`, `Person`, `Team`, `Period` entities; `PERFORMED`/`AUTHORED`/`IN_PERIOD` edges (`ontology.py:694+`) |
| Architecture/ADR | Yes | `Decision` entity, `DECIDED` edge, `decision` record type; `Document` entity + `doc_reference`; `Policy` entity + `POLICY_APPLIES_TO` |
| Implementation | Partial | `potpie resolve "<task>"` pulls pre-task context; skills installed into Claude Code / Codex / Cursor / OpenCode; the CLI does not write code |
| PR review | Partial | GitHub PR/review/source-history ingestion; PR-bundle benchmark scenarios ("cross-PR coordination", `BENCHMARK.md`); no review action |
| Test generation | No | No test-generation path in `potpie/` |
| Security/pentest | No | No security analysis; `QualityIssue` is a generic quality anchor |
| Release | Partial | `DeploymentTarget`, `Environment`, `DEPLOYED_TO`, `DEPLOYED_WITH` entities/edges model release topology but nothing performs a release |
| Monitoring/incidents | Partial | `Observation` entity, `incident_summary` and `diagnostic_signal` record types, `runbook_note`; `investigation` record type; ingest is manual/agent-written, not from a monitoring system |
| Maintenance/knowledge | Yes | `BugPattern`/`Fix`/`REPRODUCES`/`RESOLVED`/`ATTEMPTED_FIX_FAILED`/`VERIFIED`, `Preference`, `Policy`, 15 record types, `potpie record`, TTL-based freshness |

`INFERENCE` This is the broadest SDLC row coverage of the six repos by a wide margin — and it is achieved through an ontology plus integrations, not through code analysis.

## 6. Security, deployment, and license

- `FACT` **License: Apache-2.0** (`.spike/clones/potpie/LICENSE`, 192 lines of standard ASL 2.0; `README.md` "This project is licensed under the Apache 2.0 License"). No CLA-style restriction found in the LICENSE file. `INFERENCE` The ontology module and its spec dataclasses can be lifted directly with attribution.
- `FACT` **FalkorDB is the default backend** (`falkordb>=1.6.1` / `falkordblite>=0.10.0`, `potpie/context-engine/pyproject.toml:38-42`). `UNVERIFIED` FalkorDB's own licence terms — no licence text for FalkorDB exists in this repo, and no dependency was installed. This matters because FalkorDB descends from RedisGraph and its licensing has historically been non-OSI; **verify by reading FalkorDB's own LICENSE before adopting**. Neo4j (GPLv3 community / commercial enterprise) is the alternative extra (`:48-49`), which carries its own constraint.
- `FACT` Deployment: local CLI + a local daemon (`potpie/daemon/`), a local graph explorer (`potpie ui`), and an ingestion HTTP server + webhooks (`adapters/inbound/http`). Auth via `potpie login`, `potpie github login`, `potpie linear login`, with credentials in `adapters/outbound/cli_auth/credentials_store.py` (57 KB).
- `FACT` Egress: Sentry telemetry, enabled when `POTPIE_SENTRY_DSN` is present, disabled by `POTPIE_TELEMETRY_DISABLED=1` or `POTPIE_SENTRY_ENABLED=0` (`docs/telemetry/sentry.md`); Daytona sandbox for parsing; LLM provider for reconciliation and embeddings; integration APIs (GitHub/Linear/Jira/Confluence).
- `FACT` Multi-tenancy exists as a concept — "pots" (`potpie pot list` / `pot use`) scope a workspace, and account-backed "managed features" require `potpie login` — but `FACT` the managed backend raises `CapabilityNotImplemented` (`docs/context-graph/bench-plan.md:18-20`), so hosted tenancy is not shipped in OSS.
- **Prompt-injection surface.** `FACT` This is the largest of the six: the reconciliation agent reads untrusted content (PR bodies, Linear/Jira issue text, Confluence pages, source files) and is given a **write tool** (`apply_graph_mutations`) over the graph (`pydantic_deep_agent.py:6-14`). `INFERENCE` A malicious issue comment is a direct path to poisoning durable project memory that later agents read as authoritative. `FACT` Mitigations that exist are structural, not textual: `semantic_mutation_validator`, `reconciliation_validation.validate_reconciliation_plan`, and `allowed_pairs` endpoint typing constrain the *shape* of a mutation. `UNVERIFIED` whether any content-level injection defence exists — verifying would require reading the agent's system prompt assembly in `pydantic_deep_agent.py` and `event_playbooks`, which was not done.

## 7. Ideas to adopt or avoid

### Adopt
- **The three-catalog spec-driven ontology** (`ontology.py`: `ENTITY_TYPES` / `EDGE_TYPES` / `RECORD_TYPES`, with every reader/writer/validator a *view* over them and import-time coherence invariants). Specera should build its schema exactly this way: one Python/TypeScript table per concept, with a startup assertion that fails loud when the API vocabulary and the storage vocabulary drift. This is the highest-value transferable artifact in the whole spike.
- **`EdgeTypeSpec.allowed_pairs` + `allows()`** — typed endpoint constraints enforced at write time. Specera's graph should reject `Decision --DEPLOYED_TO--> Person` at the writer, not discover it in a query.
- **`singleton` edges with automatic `invalid_at` stamping** (`ontology.py:200-207`). Specera needs "the current owner of service X" to be one row that supersedes the previous one, with history preserved. Copy this flag verbatim.
- **`freshness_ttl_hours` per entity type and a `source_of_truth` class per claim** (`ontology.py:88-93`). Specera's answer to "how do you know the graph is stale" should be a schema property, not a git-diff check. Combine with `EVIDENCE_STRENGTHS = (deterministic, attested, inferred, hypothesized)` — richer than graphify's 3-value tag and applicable to non-code facts.
- **`RECORD_TYPES` as the agent-facing write vocabulary** (15 rows joining record type → anchor entity → emitted predicate → payload schema → reader include key). This is how Specera should let an agent *write back* a decision or a bug pattern without exposing raw graph mutation.
- **`@Scope` / `@Activity` wildcard endpoints** (`ontology.py:104-107`) so cross-cutting edges don't enumerate every scope label. Keeps the edge table small as entity count grows.
- **Benchmark scenarios that assert honest gaps and self-contradiction**: `v2_negative_space_missing_runbook` and `v2_conflict_surfacing` (`BENCHMARK.md`). Specera should score "did it correctly say it doesn't know" and "did it surface the conflict" as first-class metrics.
- **`ATTEMPTED_FIX_FAILED` as a first-class edge.** Recording what *didn't* work is cheap and is exactly the knowledge that dies with a departing engineer.

### Avoid
- **Name-only reference resolution with cross-file fan-out** (`tag_extract.rs:110-152`). If Specera cannot resolve a receiver, it must emit zero edges or one `AMBIGUOUS` edge with a candidate list — never one edge per same-named definition.
- **Direction-insensitive edge dedup** (`tag_extract.rs:174-181`). A directed relation must dedup on the ordered tuple only.
- **Collapsing all code into one `CodeAsset` label.** Fine for a memory graph anchored on code; fatal if the code graph is the product.
- **Letting an LLM be the only writer.** Deterministic extractors should own topology; the model should be confined to the `memory`/`timeline` categories, and every model-written claim should be forced to `evidence_strength ∈ {inferred, hypothesized}` and be visibly separable at read time.
- **Routing source code through a third-party sandbox provider** for parsing (Daytona) in a tool marketed as local.

## 8. Build, borrow, buy, integrate, or reject

**Borrow (the ontology) / Reject (the code graph).** Apache-2.0 makes `potpie/context-core/src/potpie_context_core/ontology.py` and its `EntityTypeSpec`/`EdgeTypeSpec`/`RecordTypeSpec` dataclasses directly liftable, and they are a better starting point for Specera's SDLC schema than anything else found in this spike — 24 entities and 26 predicates that already span topology, ownership, people, timeline, and memory, with bitemporality, TTL, and evidence strength designed in. The Rust code graph must be rejected outright: four node types, two edge types, name-only resolution with fan-out, and a reverse-key dedup bug. Specera's code layer should come from its own resolver (informed by GitNexus's design), joined to a Potpie-derived ontology at the `CodeAsset` seam.

## 9. Evidence

- Commit read: `b5a67742` — `b5a67742 2026-07-30 Remove legacy platform code (#1034)`. `git show --stat b5a67742` → 629 files changed, 3 insertions, **144,060 deletions**, removing the entire `legacy/` FastAPI+Neo4j+alembic platform.
- Repo: https://github.com/potpie-ai/potpie — 752 commits, first 2024-08-12, 195 in the last 6 months.
- Ontology: `potpie/context-core/src/potpie_context_core/ontology.py` (62,903 bytes) — `EntityTypeSpec` at `:113`, `EdgeTypeSpec` at `:176`, `ENTITY_TYPES` at `:288` (24 keys), `EDGE_TYPES` at `:694` (26 keys), `CANONICAL_EDGE_TYPES` at `:951`, `SYSTEM_EDGE_TYPES` at `:958`, `SINGLETON_EDGE_TYPES` at `:972`, `RECORD_TYPES` at `:1524` (15 keys). Key lists extracted with a `python3` regex scan over the file.
- Code graph: `potpie/parsing/README.md` (node/relationship vocabulary), `potpie/parsing/Cargo.toml` (16 tree-sitter grammars), `potpie/parsing/src/tag_extract.rs:68-200` (`extract_graph`, reference resolution), `:517-531` (`is_valid_reference_direction`), `potpie/sandbox/sandbox/parser_runner/runner.py` (sandboxed invocation).
- Storage: `potpie/context-engine/src/potpie_context_engine/adapters/outbound/graph/backends/` (6 backends), `.../graph/cypher.py`, `potpie/context-engine/pyproject.toml:38-49`.
- Write path: `.../adapters/outbound/reconciliation/pydantic_deep_agent.py:1-18`.
- Docs read: `README.md`, `docs/context-graph/architecture.md`, `docs/context-graph/bench-plan.md`, `potpie/context-engine/scripts/BENCHMARK.md`, `docs/telemetry/sentry.md`, `potpie/parsing/README.md`, `LICENSE`.
- Commands run (read-only; no install, build, or test execution): `git rev-parse --short HEAD`, `git log`, `git show --stat`, `find`, `grep`, `sed`, `head`, and one `python3` regex scan over `ontology.py`.
- Not verified: FalkorDB's own licence terms (no dependency installed, no vendored LICENSE in-repo); whether the reconciliation agent applies content-level prompt-injection defences.
