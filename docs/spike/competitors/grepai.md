# grepai

A Go CLI + MCP server that chunks a repo into fixed-size 512-token character windows, embeds each chunk via a local Ollama/LM Studio/OpenAI endpoint, stores chunk+vector in a single gob file (or Postgres/pgvector/Qdrant), and answers natural-language queries by brute-force cosine similarity fused with a substring scan.

## 1. Verdict

`INFERENCE` (from §2 and §4): a **narrow competitor to Specera's retrieval layer only**, and a weak one. Its genuinely good idea is operational, not algorithmic: an fsnotify daemon plus a *content-hash-addressed embedding cache* means a rename, a branch switch, or a revert re-embeds nothing (`indexer/indexer.go:376-381`, `:686-701`) — this is the cheapest correct freshness model in this whole competitor group. What kills it as a retrieval baseline: the chunker is **not AST-aware at all** — it slices files into 512-token windows with 50-token overlap on raw character offsets (`indexer/chunker.go:12-14`, `:121-122`), so function bodies are cut in half and the retrieved unit does not correspond to any program construct. The default `gob` store loads every chunk into a map and scans all of them per query (`store/gob.go:72-77`), and the lexical half of hybrid search is `strings.Contains` over every chunk (`search/hybrid.go:28-35`). `FACT`: retrieval quality is never measured — the only benchmark in the repo measures *token cost*, not precision or recall, was run by the maintainer, and dismisses correctness in one line: "Answer quality (both approaches found correct solutions)" (`docs/src/content/blog/benchmark-grepai-vs-grep-claude-code.md:149`).

## 2. Core architecture and unique mechanism

`FACT` **Chunking is character-window, not syntactic.** `indexer/chunker.go:11-14` defines `DefaultChunkSize = 512`, `DefaultChunkOverlap = 50`, `CharsPerToken = 4`. `Chunk()` walks the file by byte offset, advancing `nextPos := end - overlapChars` (`:121-122`), with `alignRuneBoundary` (`:50-56`) as the only structural concern — it aligns to UTF-8 rune starts, nothing more. `FACT`: `go-tree-sitter` appears in `go.mod:17` but is imported by only two files, `trace/extractor_ts.go` and `fsharp/binding.go` (`grep -rln go-tree-sitter --include=*.go`). The embedding index therefore has **zero syntactic awareness**.

`FACT` **Embedding providers**: `embedder/` has `ollama.go`, `lmstudio.go`, `openai.go`, `openrouter.go`, plus `synthetic.go` for tests, with `rate_limiter.go` and `retry.go`. Default per `config/config_test.go:23-32`: provider `ollama`, model `nomic-embed-text`, 768 dimensions.

`FACT` **Storage**: three backends behind `store.VectorStore` (`store/store.go:56`) — `gob.go` (default per `config/config_test.go:35`), `postgres.go` (pgvector), `qdrant.go`. The gob store keeps `chunks map[string]Chunk` and `documents map[string]Document` fully in memory (`store/gob.go:17-23`) and serialises the whole thing to one file. `store.Chunk` (`store/store.go:9-19`) persists `Content` (the raw code text) *and* `Vector []float32` *and* two hashes.

`INFERENCE` on index size (rests on `store/store.go:9-19` + the 768-dim default + 512-token/2048-char chunks with 50-token overlap): each chunk costs ~3,072 bytes of vector plus ~2,048 bytes of duplicated source text plus IDs/hashes, while the ~11% overlap means source text is stored ~1.11×. That puts the index at roughly **2.5× the size of the indexed source**, and all of it resident in RAM for the default backend. No number for this is published in the repo — `UNVERIFIED`; verifiable by running `grepai index` on a known-size repo and reading `IndexStats.IndexSize` (`store/store.go:40-45`).

`FACT` **Query path**: `store/gob.go:72-77` iterates `for _, chunk := range s.chunks` and computes `cosineSimilarity(queryVector, chunk.Vector)` for every chunk — brute force, no ANN structure. Hybrid mode fuses this with `search.TextSearch` (`search/hybrid.go:14-53`), which for each chunk lowercases the content and calls `strings.Contains` per query word, scoring `matchCount/len(words)`. Results are merged with Reciprocal Rank Fusion at k≈60 (`search/hybrid.go:58-70`), then passed through `search/boost.go` and `search/dedup.go`.

`FACT` **A second, separate graph: RPG.** `rpg/model.go` implements a "Repository Planning Graph" with six node kinds — `area`/`category`/`subcategory` (high-level, `V_H`) and `file`/`symbol`/`chunk` (low-level, `V_L`) — and six edge types: `feature_parent`, `contains`, `invokes`, `imports`, `maps_to_chunk`, `semantic_sim` (`rpg/model.go:17-39`). Feature labels come from either `LocalExtractor`, a hardcoded verb list of ~50 English verbs applied to camelCase/snake_case splits (`rpg/extractor_local.go:31-50`), or `extractor_llm.go`. The graph is persisted with gob (`rpg/store_gob.go`) and queried by BFS with Jaccard node matching (`mcp/server.go:360-396`).

`FACT` **Call graph is a third subsystem.** `trace/extractor_ts.go:32-43` registers tree-sitter grammars for exactly **9 extensions / 7 languages**: `.go`, `.js`, `.jsx`, `.ts`, `.tsx`, `.py`, `.php`, `.cs`, `.fs`/`.fsx`/`.fsi`. Symbol extraction is a hand-written `switch` per language over node types (`:95-107`, e.g. `function_declaration`, `method_declaration`, `type_declaration` for Go at `:117-190`).

`FACT` **MCP surface**: 13 tools registered in `mcp/server.go` — `grepai_search`, `grepai_trace_callers`, `grepai_trace_callees`, `grepai_trace_graph`, `grepai_refs_readers`, `grepai_refs_writers`, `grepai_refs_graph`, `grepai_index_status`, `grepai_list_workspaces`, `grepai_list_projects`, `grepai_rpg_search`, `grepai_rpg_fetch`, `grepai_rpg_explore`, `grepai_stats` (`mcp/server.go:169-421`).

## 3. Strongest capabilities

- `FACT` **Content-hash embedding cache makes re-embedding near-free on branch switches.** `indexer/indexer.go:376-381` looks up `cache.LookupByContentHash(ctx, chunk.ContentHash)` before embedding; `ContentHash` is SHA-256 of the raw chunk text *excluding the file path* (`indexer/chunker.go:25`), so an identical function that moved files costs zero embedding calls. There is a dedicated regression test for the branch-switch case (`indexer/indexer_branchswitch_test.go:28`, `TestIndexAllWithProgress_BranchSwitchSkipsBulkWithoutLookupOrEmbedding`, over a 200-file fixture).
- `FACT` **Three-stage incremental gate.** `indexer/indexer.go:139-163`: (1) skip if file mtime ≤ `lastIndexTime`; (2) otherwise hash the file and skip if `doc.Hash == file.Hash && len(doc.ChunkIDs) > 0`; (3) only then chunk and embed. Note it explicitly requires `len(doc.ChunkIDs) > 0` so a previously *failed* index is retried rather than treated as done.
- `FACT` **Watcher with debouncing.** `watcher/watcher.go` uses fsnotify with a `pending map[string]FileEvent` + timer debounce (`:36-40`), so an editor's save storm collapses to one re-index.
- `FACT` **Local-only by default** — Ollama at a local endpoint, gob file on disk. No code leaves the machine unless the user selects the OpenAI/OpenRouter embedder.
- `FACT` **Genuinely dense unit tests** for the pieces that matter: `chunker_test.go`, `indexer_test.go`, `indexer_branchswitch_test.go`, `dedup_test.go`, `hybrid_test.go`, `boost_test.go`, `rpg/model_test.go`, `rpg/indexer_incremental_test.go`, `trace/extractor_ts_*_test.go`. `rpg/` alone is 8,499 lines with test files interleaved throughout.

## 4. Critical weaknesses

- `FACT` **The retrieved unit is not a program construct.** Fixed 512-token windows advanced by byte offset (`indexer/chunker.go:121-122`) split functions arbitrarily. `INFERENCE`: a query that matches the second half of a function returns a chunk without its signature, so the agent gets a fragment it cannot act on without a follow-up file read — which negates the token-saving premise the tool is sold on.
- `FACT` **No ANN index.** `store/gob.go:72-77` is a full linear scan with cosine per chunk, in memory. `INFERENCE` (from the 2.5× size estimate above): a 1M-LOC repo produces on the order of 10^5–10^6 chunks, i.e. hundreds of MB to GB resident and a full-vector scan per query. Postgres/pgvector and Qdrant backends exist as the escape hatch, but the default configuration does not scale.
- `FACT` **Lexical search is O(chunks × query words) substring matching** (`search/hybrid.go:28-35`) with no inverted index, no stemming, no tokenisation of identifiers, and no regex. Against zoekt's trigram index this is not a comparable capability — it is a fallback.
- `FACT` **Retrieval quality is not measured.** The single benchmark in the repo (`docs/src/content/blog/benchmark-grepai-vs-grep-claude-code.md`) reports API billing, tool calls, and token counts across 5 questions on one repo (Excalidraw), carries the disclaimer "This benchmark was conducted by the grepai maintainer" (`:11`), and disposes of correctness with "Answer quality (both approaches found correct solutions)" (`:149`). There is no ground-truth set, no precision/recall/MRR, and no test asserting that a given query returns a specific chunk.
- `FACT` **Feature labels are English-verb heuristics.** `rpg/extractor_local.go:38-50` hardcodes ~50 verbs (`get`, `set`, `handle`, `validate`, …). `INFERENCE`: symbol names outside that vocabulary, non-English identifiers, or domain verbs (`reconcile`, `settle`, `provision`) fall through to whatever the fallback path produces, making the RPG hierarchy quality a function of naming convention rather than of code structure.
- `FACT` **Call-graph coverage is 7 languages** (`trace/extractor_ts.go:32-43`) — Go, JS/TS, Python, PHP, C#, F#. No Java, no Ruby, no Rust, no C/C++, no Kotlin, no Swift. `INFERENCE`: `grepai_trace_callers` silently returns empty for a Java or Rust codebase rather than reporting that the language is unsupported.
- `FACT` **No cross-repository or cross-service edges.** `EdgeImports` (`rpg/model.go:37`) is file→file/package within the indexed tree; "workspaces"/"projects" (`mcp/server.go:339-349`) are a *filtering* namespace over separate indexes, not linked graphs. Dynamic wiring — DI containers, reflection, HTTP calls between services, queue topics, config-driven dispatch — is entirely absent from the edge vocabulary.
- `FACT` **mtime is the first-line freshness gate** (`indexer/indexer.go:139-141`). `INFERENCE`: a checkout or copy that preserves mtimes while changing content (some `rsync`/archive extraction paths, some CI cache restores) is skipped before the hash check ever runs.
- `FACT` **Very young project**: first commit `73271ad 2026-01-09`, 191 commits total, single primary author (`LICENSE:3`, "Copyright (c) 2026 Yoan Bernabeu"). `INFERENCE`: bus factor 1; not a dependency to build a platform on.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No such concept in `cmd/`, `mcp/server.go`, or `rpg/` |
| Jira/work tracking | No | No issue-tracker code anywhere in the tree |
| Architecture/ADR | Partial | `rpg/` builds an area→category→subcategory→file→symbol hierarchy (`rpg/model.go:17-23`) with LLM-generated summaries (`rpg/summary.go`) — a derived map of the code, not an architecture record or decision log |
| Implementation | Partial | Retrieval only; grepai never writes code. `mcp/server.go:169` `grepai_search` returns chunks |
| PR review | No | No diff, no git-commit-range awareness; `git/` handles ignore rules and branch detection only |
| Test generation | No | Nothing in the tree |
| Security/pentest | No | Nothing in the tree |
| Release | No | `updater/` self-updates the grepai binary; unrelated to the user's release process |
| Monitoring/incidents | No | Nothing in the tree |
| Maintenance/knowledge | Partial | `grepai_trace_callers` (`mcp/server.go:197`) answers "who calls this before I change it" for 7 languages; `stats/` tracks claimed token savings |

## 6. Security, deployment, and license

`FACT` **License: MIT** (`LICENSE:1`, "Copyright (c) 2026 Yoan Bernabeu"). Fully permissive — no constraint on Specera vendoring or forking any part of it.

`FACT` **Deployment**: single Go binary, run as a local daemon (`grepai watch`) plus an MCP stdio server (`mcp/`). `compose.yaml` exists for the Postgres/Qdrant backends. There is **no auth and no tenancy model** — "workspaces" and "projects" (`mcp/server.go:339-349`) are naming scopes over local indexes, not security boundaries. `INFERENCE`: multi-user or hosted deployment would require building an authorisation layer from scratch; nothing in `daemon/` or `mcp/` distinguishes callers.

`FACT` **Network egress** is provider-dependent: `embedder/ollama.go` and `embedder/lmstudio.go` hit localhost; `embedder/openai.go` and `embedder/openrouter.go` send **raw chunk text** to a third party. The README's "100% local — Your code never leaves your machine" is therefore a `VENDOR CLAIM` true only of the default configuration.

`FACT` **Install script is `curl | sh`** (`README.md:45-47`, `install.sh`, `install.ps1`), and `updater/` self-updates the binary. `INFERENCE`: this is a supply-chain path Specera should not replicate for anything it ships into a developer environment.

`FACT` **Prompt-injection surface**: `grepai_search` returns repository text verbatim into an agent's context, and `rpg/extractor_llm.go` sends symbol names/signatures/comments to an LLM to generate feature labels. `INFERENCE`: a crafted comment in a dependency can influence the generated hierarchy labels that later steer retrieval — a persistent, index-resident injection rather than a per-query one. There is no sanitisation in `extractor_llm.go`.

## 7. Ideas to adopt or avoid

### Adopt

- **Path-independent content hashing as the embedding cache key.** `indexer/chunker.go:25` computes `ContentHash` as SHA-256 of raw chunk text *without* the file path prefix, and `indexer/indexer.go:376-381` checks it before every embed call. Specera should key every expensive derived artifact (embedding, LLM summary, parse tree) on content hash alone, so file moves, vendoring, and monorepo copies deduplicate for free. This is the single most valuable mechanism in the repo.
- **The "previous attempt failed" re-index condition.** `indexer/indexer.go:161-163` and `:737` skip a file only if `doc.Hash == hash && len(doc.ChunkIDs) > 0`. Specera should encode the same invariant: a record of "I processed this" is not sufficient; there must be *output* to prove it, or the file gets retried. This prevents silent permanent holes in an index from a transient embedder failure.
- **Debounced fsnotify with a pending-event map** (`watcher/watcher.go:36-40`) as the shape of Specera's local freshness loop, with the git-commit hook as the authoritative trigger and the watcher as the low-latency one.
- **Reciprocal Rank Fusion for merging heterogeneous rankers** (`search/hybrid.go:58-70`). Specera will have at least three signals (lexical, symbolic/graph, embedding) whose scores are not on a common scale; RRF needs no calibration between them.

### Avoid

- **Fixed-size character-window chunking** (`indexer/chunker.go:121-122`). Specera's retrieval unit must be a syntactic node (function, class, method) with its signature and enclosing scope attached, or the returned chunk is not directly usable.
- **Brute-force cosine over an in-memory map as a default** (`store/gob.go:72-77`). Whatever ships as Specera's default must be the configuration that survives the largest repo it targets.
- **`strings.Contains` as the lexical arm of a hybrid search** (`search/hybrid.go:28-35`). Use a real trigram or inverted index (see `zoekt.md`) for this half.
- **Hardcoded English verb vocabularies for semantic labelling** (`rpg/extractor_local.go:38-50`).
- **Publishing a cost benchmark and calling it a quality benchmark** (`docs/.../benchmark-grepai-vs-grep-claude-code.md:149`). Specera should ship a ground-truth query→expected-location set from day one; it is the differentiator nobody in this category has.

## 8. Build, borrow, buy, integrate, or reject

**REJECT as a component; BORROW two mechanisms.** MIT (`LICENSE:1`) permits anything, so the constraint is technical, not legal. `INFERENCE` (from `indexer/chunker.go:121-122`, `store/gob.go:72-77`, `search/hybrid.go:28-35`): the three core subsystems — chunker, vector store, lexical search — are each the naive version of something Specera needs to do well, so integrating it would mean inheriting all three and replacing them anyway. The two things worth copying are small and self-contained: the path-independent content-hash embedding cache (`indexer/indexer.go:376-381`, `:686-701`) and the failed-index retry invariant (`:161-163`). At 191 commits with a single author, it is also too young to depend on.

## 9. Evidence

- Commit read: `c4f294b` — `git -C .spike/clones/grepai rev-parse --short HEAD`
- Last commit: `c4f294b 2026-03-27 feat(search): add configurable file-level deduplication (#188)`
- History: 191 commits total, all within the last 12 months; 51 in the last 6 months; first commit `73271ad 2026-01-09 Initial commit: grepai semantic code search CLI`. Active but very young.
- License: `LICENSE:1` — MIT, Yoan Bernabeu 2026.
- Key files read: `indexer/chunker.go`, `indexer/indexer.go`, `indexer/indexer_branchswitch_test.go`, `store/store.go`, `store/gob.go`, `search/hybrid.go`, `watcher/watcher.go`, `rpg/model.go`, `rpg/extractor_local.go`, `trace/extractor_ts.go`, `mcp/server.go`, `config/config_test.go`, `go.mod`, `README.md`, `docs/src/content/blog/benchmark-grepai-vs-grep-claude-code.md`.
- Module sizes (`find <dir> -name '*.go' | xargs wc -l`): `rpg` 8,499; `embedder` 6,030; `indexer` 5,006; `mcp` 4,012; `store` 2,719; `daemon` 1,898; `search` 916; `watcher` 240.
- Commands run (all read-only): `git rev-parse`, `git log`, `ls`, `grep`, `sed`/`awk` line ranges, `wc -l`, `find`. No build, `go test`, `install.sh`, or daemon was executed.
- `UNVERIFIED`: real index-size ratio and query latency at scale. Verifiable by indexing a known repo and reading `IndexStats.IndexSize` (`store/store.go:40-45`) plus timing `grepai search` against chunk count from `grepai_index_status` (`mcp/server.go:326`).
