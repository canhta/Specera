# Zoekt

A Go text search engine for source code that builds an index of **positional trigrams** (each 3-gram stored with the rune offsets where it occurs) into mmap-able per-repository shard files, enriched with universal-ctags symbol offsets used purely as a ranking signal.

## 1. Verdict

`INFERENCE` (from §2 and §4): **not a competitor — a component, and the correct lexical foundation for Specera.** It is the fastest, cheapest, most verifiable retrieval mechanism in this whole group: exact substring and regexp with boolean operators, sub-50ms on ~2GB of text, on one machine, with **zero hallucination surface** because every hit is a literal byte range in a real file. `FACT`: Apache 2.0 (`LICENSE:1`), 1,940 commits since 2016, still maintained by Sourcegraph (HEAD `2cb19912`, 2026-07-29). `FACT`: it publishes the numbers nobody else does — index ≈ **3.5× corpus size** on disk, **1.2× corpus size of RAM**, shards capped at 4GB with ≤1GB content each (`doc/design.md`). What it will never do: any semantic reach at all — no embeddings, no cross-file reference resolution, no call graph. ctags gives it symbol *definitions* as a ranking boost, not a symbol graph. `FACT`: on a new commit, the default path re-indexes the **entire repository shard**; the file-level delta path exists but is off by default and refuses to run under several common conditions.

## 2. Core architecture and unique mechanism

`FACT` **Positional trigrams, not per-file trigram sets.** `doc/design.md` (Positional trigrams): the index stores every 3-gram with its *offset* within the file — for corpus "banana", `"ban": 0`, `"ana": 1,3`, `"nan": 2`. A substring query looks up the trigram at the pattern's start and the trigram at its end and checks they occur at the right distance apart. This differs from Russ Cox's per-file trigram sets (`swtch.com/~rsc/regexp/regexp4.html`, cited in the doc): only ~2 posting lists are intersected per query instead of many, so **posting lists can live on SSD rather than in RAM**, and the engine can pick whichever pair of trigrams in the pattern has the fewest matches ("we could search for `qui` rather than `the`").

`FACT` **Regexp is handled by extracting literal atoms.** `doc/design.md`: `(Path|PathFragment).*=.*/usr/local` is rewritten to `(AND (OR substr:"Path" substr:"PathFragment") substr:"/usr/local")`; candidate documents are then run through the real regexp engine. Query parsing (`query/`) simplifies literal regexps to substring queries (`a\.b => substring:"a.b"`).

`FACT` **Shard format** (`doc/design.md`, Index format; `index/toc.go`, `index/section.go`, `index/indexfile.go`): one file per shard, laid out to be mmap'd. Contents: file contents, filenames, content posting lists (varint-encoded), filename posting lists, branch masks, metadata. All offsets are `uint32`, so a shard must stay under 4GB, capping content at ~1GB per shard. A shard holds one repository, or several after merging into a compound shard (`index/merge.go`).

`FACT` **Branch bitmasks make multi-branch indexing nearly free.** `doc/design.md` (Branches): each blob carries a bitmask over the indexed branch set (`master=1, staging=2, stable=4`), so a file identical across three branches is stored once with mask 7.

`FACT` **UTF-8 handling**: offsets are rune offsets; a rune-index→byte-index table is stored every 100 runes, short-circuited for pure-ASCII files (`doc/design.md`, UTF-8).

`FACT` **Symbols come from universal-ctags, sandboxed with seccomp.** `index/ctags.go:44-60` runs `ctags.NewCTagsParser` over documents and attaches symbol offsets; `doc/ctags.md` requires universal-ctags built `--enable-seccomp` so "security problems in ctags cannot escalate to access to the indexing machine". Language detection is go-enry (`languages/extensions.go`, `languages/enry_vendored.go`). Symbols are used **only for scoring** — `index/score.go:152-164` adds `scoreSymbol`, `scoreWordMatch`, `scorePartialWordMatch`, and a per-language `scoreSymbolKind`. There is no reference resolution and no symbol-to-symbol edge anywhere in the index.

`FACT` **Two scoring modes**: a hand-tuned additive signal score (`index/score.go:98-194`, signals: word-boundary match, filename base match, symbol match, symbol kind, atom count) and an optional BM25 approximation enabled by `UseBM25Scoring` (`index/score.go:200-206`, `doc/design.md` Ranking).

`FACT` **Incremental has two levels.**
1. *Repo-level skip* — `Options.IndexState()` (`index/builder.go:397-446`) returns one of `missing`/`corrupt`/`version-mismatch`/`option-mismatch`/`meta-mismatch`/`content-mismatch`/`equal`. `IncrementalSkipIndexing()` (`:390-393`) skips the build only on `equal`. A branch-head change yields `content-mismatch` → **full shard rebuild**. `-incremental` defaults to `true` (`cmd/zoekt-git-index/main.go:42`) but it only skips unchanged repos; it does not make a changed repo cheap.
2. *Delta shards* — `-delta` defaults to **`false`** (`cmd/zoekt-git-index/main.go:46`). When on, `prepareDeltaBuild` (`gitindex/index.go:884`) diffs the current branch trees against the commits recorded in the existing shard metadata and indexes only changed/deleted paths into a **new stacked shard** whose `shardNum` continues from the last one (`index/builder.go:585-594`), while writing `FileTombstone` entries into the old shards (`index/builder.go:689-700`). Non-delta builds delete all existing shards first; delta builds do not (`index/builder.go:760-775`).

## 3. Strongest capabilities

- `FACT` **Published, concrete cost model — the only one in this group.** `doc/design.md`: index ≈ 3.5× corpus size on disk (2× offsets + 1× original content + metadata); ≈1.2× corpus size of RAM because posting lists stay on SSD; design goal "sub-50ms results on large codebases, such as Android (~2G text) or Chrome" on "a single standard Linux machine".
- `FACT` **Results are exact and verifiable.** Every match is a byte range in a stored file; `doc/faq.md` gives real query timings from `cs.bazel.build` (6k results in 114 files in 20ms; 4k results in 42 files in 13ms). There is no model in the loop and therefore no fabrication risk.
- `FACT` **Real query algebra.** `doc/design.md` (Query language): `Atom | AND | OR | NOT` over `ConstQuery`, `SubStringQuery`, `RegexpQuery`, `RepoQuery`, `BranchQuery`, applying to file names or contents, case-sensitive or not. `ConstQuery` enables **partial evaluation per shard** — `and[substr:"needle" repo:"zoekt"]` rewrites to FALSE on a shard for another repo, skipping it entirely.
- `FACT` **Multi-branch at near-zero marginal cost** via branch bitmasks (`doc/design.md`, Branches) — Specera's "what did this look like on the release branch" question is answerable without a second index.
- `FACT` **Purpose-built ACL story.** `doc/design.md` (Gerrit/Gitiles integration) specifies the pattern: the caller determines visible branches and the query is rewritten as `(AND original-query repo:REPO (OR branch:visible-1 branch:visible-2 …))`. Authorisation is expressed *inside the query*, so filtering happens in the index rather than post-hoc.
- `FACT` **ctags runs under seccomp** (`doc/ctags.md`), i.e. the untrusted-input parser is sandboxed — the only competitor in this group that treats its parser as an attack surface.
- `FACT` **84 `_test.go` files**, including golden-file shard tests (`testdata/golden/`, `testdata/shards/`), backward-compatibility shards (`testdata/backcompat/`), fuzz corpora (`testdata/fuzz/`), and micro-benchmarks (`index/postings_bench_test.go`, `index/case_folding_bench_test.go`, `gitindex/catfile_bench_test.go`). Delta-shard failure modes are explicitly tested (`index/builder_test.go:555,589,649`).
- `FACT` **A forward-compatible upgrade path is designed in**: `readVersions` (`index/builder.go:378-386`) accepts both the current and next index format version, and `doc/design.md` documents the swap procedure (build new-format shards, restart, delete old).

## 4. Critical weaknesses

- `FACT` **No semantic reach whatsoever.** There is no embedding code, no vector store, and no natural-language query path anywhere in the repo. A query for "the retry logic for failed payments" only works if those literal tokens appear in the code.
- `FACT` **ctags gives definitions, not references.** `index/ctags.go:44-60` attaches symbol *offsets* to documents and `index/score.go:152-164` consumes them as scoring weight. There is no call graph, no go-to-references, no cross-file resolution, and therefore no cross-repository or cross-service edge. Dynamic wiring (DI, reflection, message queues, HTTP between services) is entirely invisible — as it must be for a text engine.
- `FACT` **File-level incremental indexing is off by default and fragile.** `-delta` defaults to `false` (`cmd/zoekt-git-index/main.go:46`). When enabled, `prepareDeltaBuild` (`gitindex/index.go:884-940`) hard-fails and forces a full rebuild if: submodule indexing is on (`:885-887`); no existing shard metadata is found (`:892-894`); the branch *set* differs from what was indexed (`:918-933`); or the build-options hash changed (`:936-939`). `index/builder.go:696-700` additionally refuses delta builds for repositories inside compound shards. `INFERENCE`: the default operational reality for a new commit is **re-index the whole repository**, not "update the changed files".
- `FACT` **Delta builds accumulate shards and then give up.** `DeltaShardNumberFallbackThreshold` (`gitindex/index.go:416-422`, `:899-911`) forces a full normal index once shard count exceeds a threshold, and the code labels this verbatim: `// HACK: For our interim compaction strategy` … "This strategy obviously isn't optimal (as an example: we currently can't differentiate between 'normal' and 'delta' shards …)". `INFERENCE`: sustained high-commit-rate freshness via delta shards is not a solved problem here.
- `FACT` **Hard scaling ceilings from the format.** `uint32` offsets cap a shard at 4GB total and ~1GB of content (`doc/design.md`, Index format), and "within a shard, a single goroutine searches all documents, so the shard size determines the amount of parallelism" — a single large repository must be manually split across shards to get parallelism.
- `FACT` **Index is 3.5× the corpus** (`doc/design.md`), the largest disk multiplier of any approach in this group. This is the explicit price of exactness.
- `FACT` **Ranking quality is unmeasured.** `doc/design.md` (Ranking) opens "In absense of advanced signals (e.g. pagerank on symbol references), ranking options are limited" and lists candidate heuristics. The score constants in `index/score.go:132-164` are hand-tuned; there is no relevance benchmark, no precision/recall harness, and no golden-ranking test in the repo — only correctness tests that the right *documents* match. `INFERENCE`: zoekt guarantees recall of literal matches but makes no measured claim about ordering.
- `FACT` **Freshness at the service level is polling, not push.** `cmd/zoekt-sourcegraph-indexserver/main.go:1444` defaults `-interval` to `time.Minute` for syncing, with `merge_interval` 8h and `vacuum_interval` 24h (`:1455-1456`). `INFERENCE`: worst-case staleness after a push is the poll interval plus a full repo re-index, not seconds.
- `FACT` **Development pace has slowed markedly**: 1,940 commits total but only 79 in the last 12 months and 59 in the last 6. `INFERENCE`: mature and stable rather than abandoned (last commit 2026-07-29 added `zoekt-local-sync`), but not a project that will grow new capabilities on Specera's schedule.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | Text search only; no such concept in the tree |
| Jira/work tracking | No | `cmd/zoekt-mirror-*` integrate with code hosts (GitHub, GitLab, Gerrit, Gitea, Bitbucket) for *repository* mirroring only |
| Architecture/ADR | No | ctags symbols are a scoring signal (`index/score.go:152`), not a structural model |
| Implementation | Partial | Retrieval only — finds code, never writes it. `doc/faq.md` frames the use case as "finding the code that you should read" |
| PR review | No | No diff awareness; branches are index dimensions (`doc/design.md`, Branches), not review objects |
| Test generation | No | Nothing in the tree |
| Security/pentest | No | Grep-able patterns only. `doc/design.md` (Security) covers zoekt's *own* posture, not the indexed code's |
| Release | No | Nothing in the tree |
| Monitoring/incidents | No | Nothing in the tree |
| Maintenance/knowledge | Partial | Multi-repo, multi-branch substring/regexp search is a genuine maintenance tool for "where else does this pattern appear" |

## 6. Security, deployment, and license

`FACT` **License: Apache License 2.0** (`LICENSE:1`; per-file headers e.g. `index/ctags.go:1-13` "Copyright 2016 Google Inc."). Permissive, with an explicit patent grant — the **most reuse-friendly license posture in this group for a company shipping a commercial product**. Specera can vendor, fork, modify, and redistribute zoekt inside a closed-source product, subject only to attribution and NOTICE obligations. No copyleft, no source-available restriction, no field-of-use limit.

`FACT` **Deployment: fully self-hosted, single machine by design.** `doc/design.md` goal: "works well on a single standard Linux machine, with stable storage on SSD". `zoekt-webserver` serves a UI/API on `:6070` (`README.md`), `zoekt-indexserver` polls and reindexes. A published container image `ghcr.io/sourcegraph/zoekt` bundles the binaries, `git`, and `universal-ctags` (`README.md`). There is no SaaS and no vendor dependency.

`FACT` **Auth: none built in — by explicit design.** `doc/design.md` (Security) states the assumption: "'zoekt' is used as a public facing webserver, indexing publicly available data, serving on HTTPS without authentication. Since the UI is unauthenticated, there are no authentication secrets to steal." The intended multi-tenant pattern is that a *trusted front-end* (Gitiles in the reference design) authenticates the user and rewrites the query with the branches/repos that user may see, and "only Gitiles is allowed to talk to the search service, so it should be protected from general access". `INFERENCE`: Specera must build its own authorisation gateway in front of zoekt and must never expose it directly; the query-rewriting pattern is the supported way to do it.

`FACT` **Secrets**: git host credentials are read from files (`echo YOUR_GITHUB_TOKEN_HERE > token.txt`; `CredentialPath` in the mirror config, `README.md`). `doc/design.md` (Security) enumerates the sensitive assets as host credentials, TLS certs, and query logs.

`FACT` **Privacy**: webserver logs contain IPs and queries; the service manager deletes them after a configurable period (`doc/design.md`, Privacy).

`FACT` **Untrusted-input handling is explicitly reasoned about**: the untrusted inputs are "code in git repositories" and "search queries"; Go memory safety bounds query-parser bugs to a crash; and ctags — the one C component touching untrusted bytes — is sandboxed with seccomp (`doc/design.md` Security, `doc/ctags.md`). `INFERENCE`: **no LLM is involved anywhere, so zoekt has no prompt-injection surface at all.** If Specera pipes zoekt results into a model, the injection surface is created by Specera, not inherited.

## 7. Ideas to adopt or avoid

### Adopt

- **Positional trigrams as the lexical index** (`doc/design.md`, Positional trigrams). The specific property Specera wants is that only ~2 posting lists are touched per query, so the index can live on SSD at 3.5× corpus while RAM stays at 1.2× corpus. Specera should use zoekt itself for this rather than reimplement it — it is Apache-2.0 and battle-tested at Google/Sourcegraph scale.
- **`ConstQuery` partial evaluation for shard pruning** (`doc/design.md`, Query language). Rewriting `repo:X` to FALSE on shards for other repos means scope filters cost nothing. Specera should express *every* scope dimension it has (repo, service, team, branch, package) as an index-resident atom that can prune a shard, rather than as a post-filter on results.
- **Query-rewriting as the authorisation mechanism** (`doc/design.md`, Gerrit/Gitiles integration): resolve the caller's visible set, `AND` it into the query, never filter after ranking. This is both faster and safer than post-filtering, which leaks result counts.
- **Branch bitmasks per blob** (`doc/design.md`, Branches) — the right way to index many near-identical branches of the same repo at near-zero marginal cost. Directly applicable to Specera's need to answer questions about release branches without a second index.
- **The `IndexState` enum as the freshness contract** (`index/builder.go:365-374`): distinguishing `missing`/`corrupt`/`version-mismatch`/`option-mismatch`/`meta-mismatch`/`content-mismatch`/`equal` means "is my index stale" has a *typed* answer, and `meta-mismatch` (metadata changed, content did not) can be resolved without touching content. Specera should adopt exactly this vocabulary — it is far better than the boolean "fresh/stale" every other tool in this group uses.
- **Sandbox the parser** (`doc/ctags.md`, seccomp). Specera will run tree-sitter and/or ctags over customer code including untrusted dependencies; this is the precedent for treating that as an attack surface.

### Avoid

- **Relying on delta shards for freshness.** `-delta` is off by default (`cmd/zoekt-git-index/main.go:46`), self-describes its compaction as a `HACK` (`gitindex/index.go:899-911`), and bails out on branch-set changes, option changes, submodules, and compound shards (`gitindex/index.go:885-939`, `index/builder.go:696-700`). Specera's freshness path must be file-granular *by default and unconditionally*, which means Specera cannot rely on zoekt's incremental path for its own derived artifacts — it must track changed files itself and treat zoekt as a rebuildable secondary index.
- **`uint32` offsets in any index format.** The 4GB shard / 1GB content ceiling (`doc/design.md`) is a self-inflicted limit Specera should not replicate.
- **One goroutine per shard as the parallelism unit** (`doc/design.md`, Index format) — it makes shard sizing an operational burden pushed onto the user.
- **Shipping hand-tuned ranking constants with no relevance benchmark** (`index/score.go:132-164`). Ranking is where zoekt is weakest and where Specera can differentiate, but only if it measures.

## 8. Build, borrow, buy, integrate, or reject

**INTEGRATE.** Apache 2.0 (`LICENSE:1`) permits use inside a closed commercial product with only attribution/NOTICE obligations and grants patent rights — there is no license reason to reimplement. `INFERENCE` (from the 3.5×/1.2×/sub-50ms figures in `doc/design.md` and the 84-file test suite): rebuilding a positional-trigram engine would cost Specera many engineer-months to reach a worse place. The right shape is: run `zoekt-webserver` as an internal service behind Specera's own auth gateway using the query-rewrite ACL pattern; drive indexing from Specera's own change-detection rather than zoekt's polling `indexserver` (`cmd/zoekt-sourcegraph-indexserver/main.go:1444`, 1-minute default); and treat the zoekt shard as a **rebuildable derived artifact**, since a repo-level rebuild is the reliable path and delta shards are not. Zoekt supplies exact lexical recall with no hallucination risk; Specera's differentiation must be the semantic and structural layers *above* it, plus the retrieval-quality measurement that zoekt explicitly does not attempt.

## 9. Evidence

- Commit read: `2cb19912` — `git -C .spike/clones/zoekt rev-parse --short HEAD`
- Last commit: `2cb19912 2026-07-29 feat/local-sync: make local indexes easy to maintain (#1105)`
- History: 1,940 commits; first commit `c1c38a50 2016-04-07 codesearch: initial check-in for library`; 79 commits in the last 12 months, 59 in the last 6. Maintained by Sourcegraph since a 2017 fork of `github.com/google/zoekt` (`README.md`).
- License: `LICENSE:1` — Apache License 2.0; per-file headers "Copyright 2016 Google Inc." (e.g. `index/ctags.go:1-13`).
- Key files read: `doc/design.md` (full — index format, positional trigrams, branches, ranking, query language, security, privacy), `doc/faq.md`, `doc/ctags.md`, `doc/indexing.md`, `index/builder.go` (lines 100-130, 360-460, 580-600, 685-700, 755-775), `gitindex/index.go` (lines 390-430, 474-580, 862-960), `index/ctags.go`, `index/score.go`, `cmd/zoekt-git-index/main.go`, `cmd/zoekt-sourcegraph-indexserver/main.go:1420-1460`, `languages/`, `README.md`.
- Published cost figures, all from `doc/design.md`: index ≈3.5× corpus on disk; ≈1.2× corpus RAM; design target sub-50ms on ~2GB text on one Linux machine + SSD; shard ceiling 4GB / ~1GB content due to `uint32` offsets.
- Default flags (`cmd/zoekt-git-index/main.go:37-48`): `-submodules=true`, `-branches=HEAD`, `-incremental=true`, **`-delta=false`**, `-delta_threshold=0`.
- Test surface: 84 `*_test.go` files; `testdata/{golden,backcompat,fuzz,shards,repo,repo2}`; benchmarks in `index/postings_bench_test.go`, `index/case_folding_bench_test.go`, `gitindex/catfile_bench_test.go`.
- Commands run (all read-only): `git rev-parse`, `git log`, `ls`, `find`, `grep`, `cat`/`sed -n` on docs and Go sources, `wc -l`. No `go build`, `go install`, `go test`, or indexing run was performed.
- `UNVERIFIED`: wall-clock full-shard rebuild time for a large monorepo on a modern machine. Verifiable by timing `zoekt-git-index` against a repo of known size and dividing by corpus bytes.
