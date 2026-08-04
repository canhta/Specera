# Claude Context

A TypeScript MCP server (plus VSCode and Chrome extensions) from Zilliz that splits code into tree-sitter AST nodes for 9 languages, embeds each node with OpenAI/VoyageAI/Gemini/Ollama, stores it in Milvus/Zilliz Cloud with a parallel BM25 sparse index, and keeps the index fresh by diffing a Merkle DAG of file hashes.

## 1. Verdict

`INFERENCE` (rests on §2 and the §4 evaluation finding): a **direct competitor to Specera's retrieval layer, and the single most useful repo in this group** — not because it retrieves better, but because it is the only one that measured whether semantic retrieval helps and published the negative result. `FACT`: its own evaluation on 30 SWE-bench_Verified instances, 3 runs each, reports **F1 = 0.40 with the MCP and F1 = 0.40 with grep alone**, with the improvement column reading "Comparable" — the entire benefit is a 39.4% token reduction and 36.3% fewer tool calls (`evaluation/README.md:23-27`). That is the strongest available evidence that embedding-based code retrieval buys *efficiency*, not *accuracy*, and it comes from the vendor's own repo. Its genuinely reusable mechanisms are the AST-node splitter with a length-bounded fallback (`packages/core/src/splitter/ast-splitter.ts`) and the Merkle-DAG file synchroniser (`packages/core/src/sync/merkle.ts`). What kills it as a component: `FACT` — it hard-depends on Milvus/Zilliz Cloud (`packages/core/src/vectordb/` contains only Milvus implementations) and, by default, ships repository source to OpenAI for embedding.

## 2. Core architecture and unique mechanism

`FACT` **Splitting is AST-first with a size-bounded fallback.** `packages/core/src/splitter/ast-splitter.ts:5-13` loads nine tree-sitter grammars: `tree-sitter-javascript`, `tree-sitter-typescript`, `tree-sitter-python`, `tree-sitter-java`, `tree-sitter-cpp`, `tree-sitter-go`, `tree-sitter-rust`, `tree-sitter-c-sharp`, `tree-sitter-scala`. `getLanguageConfig` (`:86-107`) maps an extension to `{parser, nodeTypes}` where `nodeTypes` comes from a per-language `SPLITTABLE_NODE_TYPES` table. `extractChunks` (`:110-140`) walks the tree and emits a chunk whenever `splittableTypes.includes(currentNode.type)`, capturing `startLine`/`endLine` from the node's `startPosition.row`/`endPosition.row`. Any node larger than `chunkSize = 2500` chars is re-split line-wise (`:168`, `:191`), and unsupported languages fall through to `LangChainCodeSplitter` at `chunkSize = 1000` (`:40`, `:46-48`, `langchain-splitter.ts:8`). **This is the key architectural difference from grepai** — the retrieval unit is a function/class/method, not a byte window.

`FACT` **Freshness is a Merkle DAG over file hashes, not mtime and not git.** `packages/core/src/sync/merkle.ts:11-48` implements a `MerkleDAG` of SHA-256 nodes. `FileSynchronizer` (`packages/core/src/sync/synchronizer.ts:8`) hashes every eligible file (`:35`, `:45`), builds the DAG (`:134`), and persists a snapshot to `~/.context/merkle/<hash-of-rootdir>.json` (`:27-32`, `:194-209`). `checkForChanges()` (`:138-153`) rebuilds the DAG and calls `MerkleDAG.compare(old, new)` to return `{added, removed, modified}` path lists.

`FACT` **Incremental update path is per-file delete-then-reinsert.** `Context.reindexByChange` (`packages/core/src/context.ts:430-505`): get the change lists from the synchroniser; for every removed *and* every modified file call `deleteFileChunks(collectionName, relativePath)` (`:474-484`), which issues a Milvus `query` filtered on the escaped relative path and deletes the matching chunk rows (`:506-520`); then re-split and re-embed only `[...added, ...modified]` (`:487-500`). If nothing changed it returns early without touching the database (`:462-467`). `INFERENCE`: cost of a commit is O(files touched), and the observable latency is dominated by the embedding provider round-trip for the changed files — seconds for a normal commit, not a rebuild.

`FACT` **Storage is Milvus only, with genuine hybrid search.** `packages/core/src/vectordb/` contains `milvus-vectordb.ts` and `milvus-restful-vectordb.ts` and nothing else. The hybrid collection schema (`milvus-vectordb.ts:479-545`) declares a dense `vector` field, a `content` text field, and a `sparse_vector` field populated by a **server-side Milvus BM25 function** (`type: FunctionType.BM25`, `output_field_names: ["sparse_vector"]`, `:538-545`), indexed with `metric_type: MetricType.BM25` (`:579-588`). Queries go through `hybridSearch` (`:627`). Unlike grepai's `strings.Contains`, the lexical arm here is a real BM25 inverted index maintained by the database.

`FACT` **Embedding providers**: `packages/core/src/embedding/` — `openai-embedding.ts`, `voyageai-embedding.ts`, `gemini-embedding.ts`, `ollama-embedding.ts`. The README's documented quick-start requires `OPENAI_API_KEY` and a Zilliz Cloud endpoint (`README.md:38-48`, `:64-68`).

`FACT` **Indexed file types** (`packages/core/src/context.ts:58-63`): `.ts .tsx .js .jsx .py .java .cpp .c .h .hpp .cs .go .rs .php .rb .swift .kt .scala .m .mm .dart .sol .md .markdown .ipynb`. Config/data formats (`.json`, `.yaml`, `.sql`, `.sh`, `.html`, `.css`) are present but **commented out** (`:63-64`). `INFERENCE`: config-driven wiring — the exact place where dynamic dependencies live — is excluded from the index by default.

## 3. Strongest capabilities

- `FACT` **It measures retrieval quality with precision, recall, and F1 against a ground truth.** `evaluation/analyze_and_plot_mcp_efficiency.py:24-47` computes `precision = |hits ∩ oracles| / |hits|`, `recall = |hits ∩ oracles| / |oracles|`, and their harmonic mean, over 30 SWE-bench_Verified instances filtered to 15–60 minute difficulty with exactly 2 modified files, 3 independent runs per arm, GPT-4o-mini (`evaluation/README.md:13-19`). **No other repo in this competitor group has a ground-truth retrieval benchmark at all.**
- `FACT` **Chunks are syntactic units.** `ast-splitter.ts:110-140` emits whole `function_declaration`/`class_declaration`-class nodes, so a retrieved chunk carries its own signature and is directly actionable.
- `FACT` **Graceful degradation, in the right direction**: unsupported language → LangChain recursive splitter (`ast-splitter.ts:40,46-48`); oversized AST node → line-wise re-split under 2500 chars (`:168,191`). The failure mode is worse chunks, never a dropped file.
- `FACT` **Hybrid dense+sparse retrieval with the sparse side handled by the database** (`milvus-vectordb.ts:538-545,627`), so BM25 statistics stay consistent with the corpus without application-side index maintenance.
- `FACT` **Merkle snapshot is stored outside the repository** at `~/.context/merkle/` (`synchronizer.ts:27-32`), so it cannot leak into commits and survives `git clean`.
- `FACT` **Unit tests target the risky paths**, not just happy paths: `context.splitter.test.ts`, `context.embedding-error.test.ts`, `context.abort.test.ts`, `context.ignore-patterns.test.ts`, `sync/synchronizer.test.ts`, `embedding/gemini-embedding.test.ts`, `embedding/voyageai-embedding.test.ts`.

## 4. Critical weaknesses

- `FACT` **Its own benchmark shows semantic search does not improve retrieval accuracy.** `evaluation/README.md:23-27` — Average F1-Score: Baseline (Grep Only) **0.40**, With Claude Context MCP **0.40**, Improvement: "Comparable". The only wins are token usage (73,373 → 44,449) and tool calls (8.3 → 5.3). `INFERENCE`: the value proposition of the entire embedding-based category, as measured by its most rigorous member, is *context compression*, not *finding things grep cannot find*.
- `FACT` **The repo's own prose contradicts its own numbers.** `evaluation/case_study/README.md:18` asserts "the both method … is more efficient and **accurate**" and lists "Why Grep Fails" (`:22-26`), while `evaluation/README.md:23` records identical F1. `INFERENCE`: the accuracy claim rests on two hand-picked case studies (`django_14170`, `pydata_xarray_6938`), not on the 30-instance measurement. Treat the accuracy framing as `VENDOR CLAIM`; the F1 table is the `FACT`.
- `FACT` **Benchmark scope is narrow**: n=30, filtered to exactly 2 modified files, GPT-4o-mini "for cost-effective considerations" (`evaluation/README.md:15-17`), and results tested against `claude-context-mcp@0.1.0` (`evaluation/README.md` reproduction section) — a version far behind HEAD. `UNVERIFIED`: whether the F1 parity holds with a stronger model or on multi-file changes. Verifiable by re-running `run_evaluation.py` with a larger subset and a frontier model.
- `FACT` **Single vector-store vendor.** `packages/core/src/vectordb/` implements Milvus and Milvus-REST only; `zilliz-utils.ts` handles Zilliz Cloud specifics. There is no pgvector, Qdrant, or local-file backend. `INFERENCE`: adopting this library means adopting Zilliz's infrastructure, from a repo authored by Zilliz.
- `FACT` **Merkle rebuild is a full re-hash of the tree.** `synchronizer.ts:138-145` calls `generateFileHashes(dir)` over the whole codebase on every `checkForChanges()`. `INFERENCE`: change detection is O(all files, all bytes) even when one file changed — cheap on an SSD for a mid-size repo, but a linear scan of every byte on a large monorepo, and materially worse than reading `git diff --name-only`.
- `FACT` **The Merkle DAG never consults git.** `synchronizer.ts` imports only `fs`, `path`, `crypto`, and `./merkle`. `INFERENCE`: there is no commit identity attached to the index, so nothing can answer "which revision is this index at" or "is this index stale relative to origin/main" — an index is only ever "matches the working tree at the last check".
- `FACT` **No symbol graph, no references, no call edges.** `context.ts` exposes `indexCodebase`, `reindexByChange`, `semanticSearch`, `hasIndex`, `clearIndex` (`:355,430,531,673,683`). The AST is used solely to decide chunk boundaries and is then discarded — `extractChunks` (`ast-splitter.ts:110-140`) keeps only `{content, startLine, endLine, language, filePath}`. Cross-file, cross-repo, and cross-service edges do not exist in any form.
- `FACT` **Config files are excluded by default** (`context.ts:63-64`, commented-out `.json/.yaml/.xml/.sql/.sh` entries). `INFERENCE`: DI wiring, route tables, queue bindings, and infrastructure-as-code are invisible to retrieval — precisely the dynamic-dependency blind spot.
- `FACT` **9 AST languages vs 24 indexed extensions** (`ast-splitter.ts:86-104` vs `context.ts:58-63`). Ruby, PHP, Swift, Kotlin, Objective-C, Dart, Solidity, and Markdown are indexed but fall to the 1000-char LangChain splitter (`ast-splitter.ts:46-48`), so chunk quality is silently two-tier by language with no signal to the caller.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No such concept in `packages/core/src/` or `packages/mcp/src/` |
| Jira/work tracking | No | No issue-tracker integration in the tree |
| Architecture/ADR | No | The AST is discarded after chunking (`ast-splitter.ts:110-140`); no structural model is retained |
| Implementation | Partial | Retrieval only — `semanticSearch` (`context.ts:531`); it never edits code |
| PR review | No | No git/diff awareness anywhere; the synchroniser deliberately uses filesystem hashes, not commits (`sync/synchronizer.ts`) |
| Test generation | No | Nothing in the tree |
| Security/pentest | No | Nothing in the tree; `.env`/`.env.*` are ignore patterns (`context.ts:100-101`) |
| Release | No | Nothing in the tree |
| Monitoring/incidents | No | Nothing in the tree |
| Maintenance/knowledge | Partial | `.md`/`.ipynb` are indexed alongside code (`context.ts:62`), so design docs are retrievable in the same query as code — but with no link between them |

## 6. Security, deployment, and license

`FACT` **License: MIT** (`LICENSE:1`, "Copyright (c) 2025 Zilliz"). Fully permissive; the `ast-splitter.ts` and `merkle.ts`/`synchronizer.ts` files can be lifted directly with attribution. No copyleft or source-available constraint anywhere in the repo.

`FACT` **Deployment is SaaS-leaning by default.** The documented quick start requires a Zilliz Cloud API key and endpoint (`README.md:38-48`) and an `OPENAI_API_KEY` (`README.md:50-56`). Self-hosting is possible — Milvus is open source and `ollama-embedding.ts` exists — but neither is the documented path.

`FACT` **Egress: raw source code leaves the machine on the default configuration.** `openai-embedding.ts` sends chunk text to OpenAI; the vectors *and* the full `content` field (`milvus-vectordb.ts:492`, "Full text content for BM25 and storage") are then stored in Zilliz Cloud. `INFERENCE`: for Specera's target customers this is a two-vendor data-residency question — the embedding provider sees the code, and the vector database stores it in plaintext, not just as vectors.

`FACT` **Secrets handling**: API keys come from environment variables managed by `packages/core/src/utils/env-manager.ts`; `.env` and `.env.*` are in the default ignore list (`context.ts:100-101`) so secrets files are not indexed. There is no auth layer, no tenancy model, and no per-user scoping in `packages/mcp/` — a collection name is derived from a hash of the codebase path (`context.ts:289`), which is a namespace, not a boundary.

`FACT` **Prompt-injection surface**: `semanticSearch` returns raw repository text into the agent's context. There is no sanitisation step between `deduplicateResults` (`context.ts:646`) and the MCP response. `INFERENCE`: standard for this category, and Specera must assume any retrieved chunk is attacker-influenced text.

`FACT` **Distribution surface is broad**: npm packages `@zilliz/claude-context-core` and `@zilliz/claude-context-mcp`, a VSCode Marketplace extension, and a Chrome extension (`packages/chrome-extension/`) that talks to Milvus directly from the browser (`packages/chrome-extension/src/milvus/`). `INFERENCE`: the Chrome extension implies Milvus credentials living in browser storage (`packages/chrome-extension/src/storage/`) — not a pattern to copy.

## 7. Ideas to adopt or avoid

### Adopt

- **AST-node chunking with a two-level fallback.** Copy the exact shape of `ast-splitter.ts`: split on a per-language allow-list of node types (`:86-104`), re-split any node over a byte budget line-wise (`:168,191`), and fall back to a generic recursive splitter for unsupported languages (`:40,46-48`). Specera should additionally *record which tier produced each chunk*, so retrieval quality can be attributed by language — the one thing this implementation omits.
- **Delete-by-path-then-reinsert as the incremental primitive.** `context.ts:474-484` + `:506-520` treat "modified" identically to "removed then added". This avoids the whole class of orphaned-chunk bugs that in-place update produces, at the cost of one extra delete. Specera should adopt it for every derived artifact keyed to a file.
- **A published precision/recall/F1 harness as a first-class artifact of the repo.** `evaluation/analyze_and_plot_mcp_efficiency.py:24-47` plus a SWE-bench_Verified subset generator (`generate_subset_json.py`) is roughly 500 lines of work and is the single credible differentiator available in this category. Specera should ship its equivalent before shipping the retriever, and should hold itself to beating F1 = 0.40, which is now a published, citable baseline.
- **Server-side BM25 as the lexical arm** (`milvus-vectordb.ts:538-545`) rather than an application-maintained inverted index — the corpus statistics stay correct across incremental writes for free. If Specera uses Postgres, the equivalent is a `tsvector` column with a GIN index maintained by a generated column.
- **Snapshot state outside the repository** (`synchronizer.ts:27-32`, `~/.context/merkle/`). Serena writes its cache into `.serena/` inside the repo; this is the better choice.

### Avoid

- **Full-tree re-hashing as the change-detection mechanism** (`synchronizer.ts:138-145`). Specera should use `git diff --name-only <indexed-commit>..HEAD` as the primary signal, with content hashing as verification only for the changed set, and should store the indexed commit SHA so staleness is answerable.
- **Indexing without recording a revision.** No git identity is attached to the index anywhere in `sync/`; Specera must make "which commit is this index at" a first-class, queryable property.
- **Excluding config and infrastructure files from the index** (`context.ts:63-64`). These are where dynamic wiring lives and are the hardest thing for any competitor here to see.
- **Discarding the parse tree after chunking** (`ast-splitter.ts:110-140`). Specera pays the tree-sitter cost anyway; the symbol names, signatures, and call sites should be persisted as graph edges in the same pass.
- **Coupling the core library to one vector database vendor** (`packages/core/src/vectordb/` = Milvus only).

## 8. Build, borrow, buy, integrate, or reject

**BORROW (two files and the evaluation method); REJECT as a runtime dependency.** MIT (`LICENSE:1`) imposes no constraint, so this is a pure engineering call. `INFERENCE` (from `packages/core/src/vectordb/` containing only Milvus backends and from `README.md:38-56` making Zilliz Cloud + OpenAI the documented path): integrating the library means adopting Zilliz's storage and, by default, exporting customer source to two third parties — unacceptable for Specera's likely enterprise posture. What is worth taking is small and self-contained: `packages/core/src/splitter/ast-splitter.ts` (AST chunking with graceful fallback) and `packages/core/src/sync/merkle.ts` + `synchronizer.ts` (structural diffing), both re-implementable in a day. The most valuable thing in the repo is not code at all — it is `evaluation/README.md:23-27`, which gives Specera a published F1 = 0.40 baseline and the evidence that a semantic-only retriever is not a differentiator.

## 9. Evidence

- Commit read: `6fc318b` — `git -C .spike/clones/claude-context rev-parse --short HEAD`
- Last commit: `6fc318b 2026-07-14 fix(mcp): derive default version from package metadata`
- History: 217 commits total; 122 in the last 12 months; 70 in the last 6 months; first commit `e112a55 2025-06-06`. Actively maintained.
- License: `LICENSE:1` — MIT, Zilliz 2025.
- Key files read: `packages/core/src/splitter/ast-splitter.ts`, `packages/core/src/splitter/langchain-splitter.ts`, `packages/core/src/sync/merkle.ts`, `packages/core/src/sync/synchronizer.ts`, `packages/core/src/context.ts` (lines 58-63, 355-520, 531-690), `packages/core/src/vectordb/milvus-vectordb.ts` (lines 479-627), `packages/core/src/embedding/`, `evaluation/README.md`, `evaluation/analyze_and_plot_mcp_efficiency.py`, `evaluation/case_study/README.md`, `README.md`.
- Headline evaluation numbers (`evaluation/README.md:23-27`): Avg F1 0.40 vs 0.40 ("Comparable"); Avg tokens 73,373 → 44,449 (−39.4%); Avg tool calls 8.3 → 5.3 (−36.3%). n=30 SWE-bench_Verified instances, 3 runs per arm, GPT-4o-mini.
- Commands run (all read-only): `git rev-parse`, `git log`, `ls`, `find`, `grep`, `sed -n` line ranges. No `pnpm install`, build, or evaluation script was executed.
- `UNVERIFIED`: index size relative to source. The Milvus collection stores the full chunk text plus a dense vector plus a BM25 sparse vector per chunk (`milvus-vectordb.ts:492-505`); no size ratio is published. Verifiable by indexing a known repo and reading Milvus collection statistics.
