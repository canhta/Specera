# S2 — Graph storage and data layer

**Decision: one relational schema with a typed edge table, run on SQLite (`node:sqlite`) in
the CLI and PostgreSQL on the server. Recursive CTEs for traversal. No graph database.**

No embedded graph engine exists that is simultaneously alive, permissively licensed, and mature.
Every one fails a gate below. That is the finding, not a compromise.

## Liveness / licence gate (all via GitHub API, 2026-08-04)

| Candidate | SPDX | Stars | Last push | Archived | Verdict |
|---|---|---|---|---|---|
| `sqlite/sqlite` | Public Domain (`LICENSE.md`; API says NOASSERTION) | 10152 | 2026-08-03 | false | **KEEP — CLI engine** |
| `postgres/postgres` | PostgreSQL Licence (`COPYRIGHT`; API says NOASSERTION) | 21687 | 2026-08-04 | false | **KEEP — server engine** |
| `WiseLibs/better-sqlite3` | MIT | 7407 | 2026-07-29 | false | Fallback only — needs native build |
| `electric-sql/pglite` | Apache-2.0 | 15711 | 2026-07-29 | false | **RUNNER-UP** (see below) |
| `apache/age` | Apache-2.0 | 4717 | 2026-07-17 | false | Escape hatch, not day one |
| `duckdb/duckdb` | MIT | 39951 | 2026-08-03 | false | Analytics tier later; not OLTP |
| `kuzudb/kuzu` | MIT | 4027 | 2025-10-10 | **true** | **KILL — archived** |
| `cozodb/cozo` | MPL-2.0 | 4076 | 2024-12-04 | false | **KILL — 20 months dormant, 1 maintainer** |
| `cayleygraph/cayley` | Apache-2.0 | 15052 | 2026-07-22 (bot) | false | **KILL — last human commit 2024-07-06** |
| `indradb/indradb` | MPL-2.0 | 2458 | 2025-08-16 | false | **KILL — single maintainer** |
| `HelixDB/helix-db` | Apache-2.0 | 5697 | 2026-07-17 | false | **KILL — 22 contributors, pre-1.0** |
| `surrealdb/surrealdb` | **BSL 1.1** (`LICENSE`, change date 2030-01-01) | 32798 | 2026-07-06 | false | **KILL — not open source** |
| `memgraph/memgraph` | **BSL 1.1 + Memgraph Enterprise Licence** (`LICENSE`) | 4311 | 2026-08-04 | false | **KILL — not open source** |
| `FalkorDB/FalkorDB` | **SSPL v1** (`LICENSE.txt`) | 5157 | 2026-08-04 | false | **KILL — SSPL** |
| `neo4j/neo4j` | **GPL-3.0** | 17004 | 2026-07-08 | false | **KILL** (already rejected) |
| `terminusdb/terminusdb` | Apache-2.0 | 3373 | 2026-08-04 | false | Interesting, not picked — WOQL, small team |
| `oxigraph/oxigraph` | Apache-2.0 | 1793 | 2026-08-03 | false | Not picked — RDF reification tax, bus factor |
| `dgraph-io/dgraph` | Apache-2.0 | 21764 | 2026-07-31 | false | Not picked — server-only, distributed, overkill |
| `networkx/networkx` | BSD-3-Clause (`LICENSE.txt`) | 17153 | 2026-08-03 | false | Library, not a store — see graphify |
| `tursodatabase/libsql` | MIT | 17083 | 2026-07-24 | false | Optional later; Turso is mid-rewrite |

`FACT` **Kuzu is archived** — confirmed `archived=true`, `pushed=2025-10-10`. One API call.
`FACT` **Neo4j consequence**: Community Edition is GPL-3.0, so bundling it in a self-host image or
Helm chart makes Specera's distribution GPL-entangled and encumbers customers' own modifications.
The *driver* is Apache-2.0 — irrelevant, we would still be shipping the server.
`FACT` **potpie's engine depends on SSPL FalkorDB** (`potpie/context-engine/pyproject.toml:38,40`),
but `potpie/context-core/pyproject.toml:13` depends on **pydantic only** — reusing the Apache-2.0
ontology is clean and carries no SSPL taint. Do not pull in `context-engine`.

## Evidence from the corpus

`FACT` **graphify cannot serve concurrent multi-user queries.** `graphify/serve.py:25`
`_load_graph()` calls `json_graph.node_link_graph(data)` (`serve.py:49`) — the whole graph is
deserialised from `graph.json` into a NetworkX object in process memory. No store, no transaction,
no reader/writer separation; `graphify/watch.py:1264` rewrites the file atomically because "a crash
mid-write must not leave a truncated graph.json". That is a file, not a database. Specera uses
graphify as an extraction *provider* only; its storage never enters.

`FACT` **codegraph achieves zero-daemon, zero-native-build with `node:sqlite`.**
`src/db/sqlite-adapter.ts:4-45` wraps Node's built-in `DatabaseSync` behind a better-sqlite3-shaped
interface; `package.json` lists better-sqlite3 only under `devDependencies` (types), so `npm i`
compiles nothing. `src/db/index.ts:33` sets `journal_mode = WAL`; `src/mcp/query-worker.ts:13`
notes each worker owns its own read connection because "WAL allows N concurrent readers".
Requirement 3, proven in a shipped product.

`FACT` **codegraph discards confidence at write time.** `src/db/schema.sql:45-56` — the `edges`
table has `provenance TEXT DEFAULT NULL` and **no confidence column at all**, while the resolver
computes real confidence (`src/resolution/import-resolver.ts:1271` `confidence: 0.95`, ~20 more
sites) and thresholds it *in memory* (`src/resolution/index.ts:963,978`) before throwing the number
away — `src/db/queries.ts:526` inserts exactly `source, target, kind, metadata, line, col,
provenance`. Provenance itself was bolted on later (`src/db/migrations.ts:42`,
`ALTER TABLE edges ADD COLUMN provenance`). Nothing in the corpus filters by confidence by default.

`FACT` **codegraph traverses in application code, not SQL.** `src/graph/traversal.ts:543`
`getImpactRecursive()` is JS recursion issuing one `getOutgoingEdges`/`getIncomingEdges` query per
node per hop; `grep -rn "WITH RECURSIVE" src/` returns **nothing**. N+1 per traversal — the thing
Specera must not copy, and the reason recursive CTEs matter.

`FACT` **potpie's ontology already models what we need.** `ontology.py:160-165` puts
`fact_family`, `source_of_truth`, `freshness_ttl_hours` on every `EntityTypeSpec`;
`ontology.py:92` defines `EVIDENCE_STRENGTHS = ("deterministic","attested","inferred","hypothesized")`,
default `"inferred"`. `ontology.py:200-207` is the bitemporal core: a `singleton` edge means
"(subject, predicate) admits one live object at a time" and the writer "auto-stamps `invalid_at`
on any prior live claim"; `ontology.py:502,814` use `valid_at` as event time, timeline being
"a read-time query over `valid_at`". **Implication:** freshness and evidence strength are
*type-level* (a column on the type catalog, seeded by migration) while validity is *row-level*
— so a TTL policy change is a data update, not a reindex.

`FACT` **bloop's two-key content-addressed cache** (`indexes/file.rs:56-87`, Apache-2.0):
`cache_keys()` blake3-hashes `SCHEMA_VERSION + relative_path + repo_ref + file_contents +
filter_state` into `semantic_hash`, then folds branches in for `tantivy_hash`; `cache.rs:75-106`
explains the two strengths, `cache.rs:114` `is_fresh(keys)`. The design is right; the **flaw to
fix** is line 59 — the global `SCHEMA_VERSION` in the key means any schema bump invalidates every file.

`FACT` **0 down-migrations, corroborated.** sourcebot ships 88 Prisma migrations
(`packages/db/prisma/migrations/`) and `find … -name "*down*"` returns **0**.

## Schema shape: relational, with a typed edge table

- **Against RDF/triples** (Oxigraph, TerminusDB): an edge carrying provenance + confidence + two
  time ranges is not a triple. You reify (one edge → 5+ triples, every confidence filter becomes a
  join) or use named graphs / RDF-star, pushing the filter into syntax most tooling handles badly.
  Requirement 1 — *default* filtering — is exactly what RDF makes expensive.
- **Against native property graphs**: technically the best fit, and every candidate is archived
  (Kuzu), dormant (Cozo), copyleft/source-available (Neo4j, Memgraph, FalkorDB, SurrealDB), or
  immature (HelixDB).
- **For relational**: edge properties are just columns — provenance/confidence/validity are
  first-class and *indexable*, partial indexes make the default filter free, and the same DDL
  runs unchanged on CLI and server.

```sql
CREATE TABLE edges_raw (            -- application code never names this table
  id TEXT PRIMARY KEY,              -- content hash of (src,dst,type,extractor_version)
  src_id TEXT NOT NULL, dst_id TEXT NOT NULL,
  edge_type   TEXT NOT NULL REFERENCES edge_type_catalog(edge_type),
  provenance  TEXT NOT NULL CHECK (provenance IN ('EXTRACTED','INFERRED','AMBIGUOUS')),
  confidence  REAL NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  evidence    TEXT,                 -- JSON: file, line, rule id, extractor
  commit_sha  TEXT,                 -- "what did this look like at commit X"
  valid_at    INTEGER NOT NULL,     -- event time (commit/deploy/incident)
  invalid_at  INTEGER,              -- NULL = live claim (potpie ontology.py:203)
  observed_at INTEGER NOT NULL, retracted_at INTEGER,   -- Specera's belief window
  input_digest TEXT NOT NULL        -- blake3(extractor_version || source_content_hash)
);
CREATE INDEX edges_live_src ON edges_raw(src_id, edge_type)
  WHERE invalid_at IS NULL AND retracted_at IS NULL AND confidence >= 0.8;
CREATE VIEW edges AS SELECT * FROM edges_raw
  WHERE invalid_at IS NULL AND retracted_at IS NULL
    AND confidence >= 0.8 AND provenance <> 'AMBIGUOUS';
```

**The trick that makes requirement 1 structural, not a convention:** the base table is `edges_raw`
and the *view* is named `edges`. The naive query — what a tired engineer or an LLM writes — is
`SELECT … FROM edges`, already filtered; seeing raw data requires deliberately typing `_raw`.
Reinforced three ways: (a) Postgres `REVOKE SELECT ON edges_raw` from the app role — engine-enforced;
(b) SQLite has no grants, so a CI lint fails any `edges_raw` outside `packages/storage/`; (c) the
repository layer's `withProvenance({minConfidence, includeAmbiguous})` is the sole opt-out, and logs.

**Traversal** is a recursive CTE over the view — identical in SQLite and Postgres, one query per
traversal instead of codegraph's N+1:

```sql
WITH RECURSIVE impact(id, depth, path) AS (
  SELECT :root, 0, :root
  UNION ALL
  SELECT e.dst_id, i.depth+1, i.path || '>' || e.dst_id
  FROM impact i JOIN edges e ON e.src_id = i.id
  WHERE i.depth < :max_depth AND instr(i.path, e.dst_id) = 0   -- cycle guard
) SELECT * FROM impact;
```

Time travel is one extra predicate against the *raw* table:
`WHERE valid_at <= :t AND (invalid_at IS NULL OR invalid_at > :t)`. And because edges are never
`UPDATE`d — a changed claim inserts a new row and stamps `invalid_at` on its predecessor — the
edge history *is* the append-only audit log the enterprise requirement asks for. No second subsystem.

## Migration strategy

1. **Two version counters.** `schema_version` (DDL ladder — exactly codegraph's
   `src/db/migrations.ts`, 8 versions, all additive `ALTER TABLE`) and a per-row
   `extractor_version`.
2. **Expand/contract, forward-only.** The 0/105 down-migration finding is not a discipline failure
   to correct — it is evidence that down-migrations rot untested. Every migration is additive
   (`ADD COLUMN … DEFAULT`, `CREATE TABLE`, `CREATE INDEX`); destructive changes span three
   releases (write both → backfill → stop reading old → drop at N+2). Rollback is then "deploy the
   previous binary", which still reads the newer schema. One integration test per migration runs
   release N-1's query set against release N's schema.
3. **No full reindex on schema change.** `input_digest` hashes
   `extractor_version || source_content_hash` and **not** the global schema version, so a DDL
   change invalidates nothing and a Gherkin-parser fix reindexes only feature files. This is
   bloop's `cache_keys` (`indexes/file.rs:56-87`) with the `SCHEMA_VERSION` term (`file.rs:59`)
   deliberately split out — bloop forces a global reindex on every schema bump; ours does not.
4. **When reindex is unavoidable it is cheap**: the first slice's inputs are feature files and test
   results — thousands of rows, not millions — re-extracted per file in parallel with a
   digest-unchanged skip.

## CLI/server split, priced

One schema, one logical model, **two SQL engines**. This is *not* dual-write: the CLI is a
producer emitting an idempotent, content-addressed batch (rows keyed by `id` = content hash) that
the server `UPSERT`s. Because IDs are content hashes, re-sending a batch is a no-op — sync needs
no reconciliation protocol.

The real cost is **dialect divergence**, and it is bounded: recursive CTEs, `ON CONFLICT`, partial
indexes and JSON columns exist in both; the gaps are types (`TEXT`/`INTEGER` vs `uuid`/`timestamptz`),
JSON accessors (`json_extract` vs `->>`), and concurrency (WAL single-writer vs MVCC). Mitigation:
DDL from one definition with two dialect emitters, all SQL confined to `packages/storage/`, one
conformance suite run against both engines in CI. **Estimate: 2-3 dev-weeks up front, then a small
per-feature tax** — cheaper than two data models, far cheaper than requiring Docker for `specera index`.

## Runner-up, and what would change my mind

**Runner-up: PGlite (Apache-2.0, 15711 stars, pushed 2026-07-29) in the CLI, Postgres on the
server** — one engine, one dialect, zero divergence tax. Not chosen: WASM (single-connection,
slower bulk insert, ~3 MB payload) and far younger than SQLite. **Experiment that flips it:** index
a 10k-file monorepo's feature files with both; if PGlite lands within 2x of SQLite's wall clock and
its file format is declared stable, collapse to Postgres everywhere and delete the dialect layer.

Also flips the decision: (a) a permissive, actively-maintained *embedded* property graph with edge
properties appearing — none exists today; (b) recursive CTEs failing at scale (>6 hops over >10M
edges), whose fix is additive rather than a rewrite: add **Apache AGE** (Apache-2.0, ASF, 99
contributors, PG18 RC 2026-07-09) as a server-side openCypher accelerator *inside the same
Postgres*. Not day one — AGE needs an extension build, is unavailable on most managed Postgres,
and cannot run in the CLI.

---

## Summary

**Top recommendation:** relational schema, typed temporally-versioned edge table; `node:sqlite` in
the CLI (zero daemon, zero native build — proven by codegraph), Postgres on the server; recursive
CTEs for traversal; provenance/confidence as indexed columns with the *safe* query as the default
one (base table `edges_raw`, filtered view named `edges`); append-only edge history doubling as the
audit log; forward-only expand/contract migrations with a bloop-style `input_digest` that excludes
schema version, so DDL changes never trigger a reindex.

**Biggest risk:** the two-engine SQL surface. Every feature is written and tested twice and the
discipline decays under deadline — one Postgres-only `jsonb` operator or `generate_series` and the
CLI silently diverges. CI conformance runs against both engines mitigate it, but it is a permanent
tax that only PGlite maturing would retire.

**Could not verify:** (a) whether `node:sqlite` is stable rather than experimental in our target
Node LTS — codegraph explicitly mutes the warning (`src/extraction/wasm-runtime-flags.ts:45`; `:59`
notes ">= 22.5"), implying experimental at their pin. Check before committing; better-sqlite3 (MIT,
alive) is the fallback at the cost of a native build. (b) `falkordblite`'s licence — PyPI claims
BSD but `github.com/FalkorDB/falkordblite` returns null from the API; moot, we reject FalkorDB.
(c) Recursive-CTE performance at 10M+ edges — unmeasured; the experiment is named above.
