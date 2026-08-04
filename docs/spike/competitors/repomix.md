# Repomix

A Node CLI (also an MCP server, a hosted pack API, and a browser extension) that walks a git repo, optionally strips function bodies with tree-sitter, scans every file with secretlint, and emits one XML/Markdown/JSON/plain file with per-file token counts.

## 1. Verdict

Component, not a competitor — but the **best-engineered** tool in the repo-packing category and the only one of the three (vs `gitingest`, `code2prompt`) that is not a commodity. Two things justify reading it: it runs a real secret scanner (`@secretlint/core` with the recommended preset) over every file **on by default** before anything leaves the machine, and it has 16 hand-written tree-sitter query sets that reduce a file to imports + signatures + comments. Everything else — token counting, ignore handling, output formats, remote clone — is table stakes that any of the three do. What kills it as a competitor: it is stateless and one-shot. There is no index, no incremental update, no notion of a stale artifact; each run re-walks, re-parses, and re-scans the entire repo. And its own security guarantee has a documented hole: secrets found in git diffs and git logs are logged as a warning and **shipped anyway**.

## 2. Core architecture and unique mechanism

Single-pass pipeline in `src/core/packager.ts`: discover files → read → (optionally) compress → security-scan → filter → count tokens → render template → write.

**Secret scanning (the distinguishing mechanism).** `FACT`
- Engine is `@secretlint/core` + `@secretlint/secretlint-rule-preset-recommend` (`package.json:85-86`) — a maintained third-party rule preset, not homegrown regexes.
- `src/core/security/workers/securityCheckWorker.ts:85-92` builds a `SecretLintCoreConfig` with the recommend preset as its only rule and caches it at module scope (`:95`); `runSecretLint` (`:119-151`) calls `lintSource()` per item. Line 141 carries the comment "Do not log the actual messages to prevent leaking sensitive information" — findings are reported as a count, never a value.
- `src/core/security/securityCheck.ts:24-130` batches raw files **plus** git-diff and git-log text (`:38-65`) into worker threads, batch size 50, capped at 2 workers (`:22, :84`).
- **Enforcement is whole-file exclusion, not redaction.** `src/core/security/filterOutUntrustedFiles.ts:4-8` is a one-line filter: `rawFiles.filter(f => !suspiciousFilesResults.some(r => r.filePath === f.path))`. A file with one leaked key is dropped in its entirety; the surrounding code is lost too. There is no line-level masking. `FACT` (verified by reading the file)
- **Git diffs and logs are exempt.** `src/core/security/validateFileSafety.ts:10-12` states the intent verbatim: *"Returns Git diff results separately so they can be included in the output even if they contain sensitive information."* `logSuspiciousContentWarning` (`:54-65`) emits `"Security issues found in Git diffs, but they will still be included in the output"` and the content is passed through. `FACT` (verified by reading the file)
- **Default on**: `src/config/configSchema.ts:166` — `enableSecurityCheck: v.optional(v.boolean(), true)`. Off via `--no-security-check` (`src/cli/cliRun.ts:179`). `FACT` (verified)
- The worker contains an elaborate patch neutralising `@secretlint/profiler`'s `performance.mark` calls to avoid quadratic bookkeeping (`securityCheckWorker.ts:12-64`) — evidence this scan is on the hot path for every file of every run, not a rarely-used flag. `INFERENCE` from that code's existence.

**Tree-sitter compression.** `--compress`, default **false** (`src/config/configSchema.ts:139`). `FACT` Engine is `web-tree-sitter` (WASM) + `@repomix/tree-sitter-wasms` (`package.json:81,84`). 16 languages, each with a query set as a TypeScript template literal under `src/core/treeSitter/queries/`: C, C#, C++, CSS, Dart, Go, Java, JavaScript, PHP, Python, Ruby, Rust, Solidity, Swift, TypeScript, Vue (registry `src/core/treeSitter/languageConfig.ts:64-161`). Kept nodes (per `queries/queryTypescript.ts:1-73`): import statements, comments, function/method/class/interface/module/type-alias/enum declarations and their names, type references, `new`-expression class references, arrow-function assignments. Function bodies are dropped. `FACT` `queries/README.md:1-27` credits Aider and Cline as the source of these queries — i.e. the same lineage as `aider`'s `.scm` tag files. Per-language behaviour lives in `src/core/treeSitter/parseStrategies/` with an explicit statelessness contract (`BaseParseStrategy.ts:30-35`) because strategy instances are shared across all files of a language.

**Token counting.** `gpt-tokenizer` (`package.json:83`) via `src/core/metrics/TokenCounter.ts:1-2,36`. Five encodings: `o200k_base` (default), `cl100k_base`, `p50k_base`, `p50k_edit`, `r50k_base` (`src/core/metrics/tokenEncodings.ts:3`; default at `configSchema.ts:169`). Counts are **per-file** in a worker pool (batch 50, `src/core/metrics/calculateFileMetrics.ts:17-113`) and rolled up into a directory token-count tree (`src/core/metrics/buildTokenCountStructure.ts`), plus a whole-output total (`calculateOutputMetrics.ts`). `FACT`

**The only persistent state in the product** is a token-count cache: `src/core/metrics/tokenCountCache.ts`, a JSON file at `$TMPDIR/repomix/cache/token-counts.json`, keyed `${encoding}:${byteLength}:${md5_16(content)}` (`:327-331`), capped at `MAX_CACHE_ENTRIES = 100_000` with FIFO eviction (`:21, :262-275`), atomic tmp-file+rename writes (`:290-293`), disabled by `REPOMIX_TOKEN_CACHE=0` (`:75-80`). It is content-addressed and global, so it is shared across repos. `FACT`

**Remote repos.** Two paths in `src/cli/actions/remoteAction.ts`: GitHub codeload tarball streamed and gunzipped with no `git` binary (`src/core/git/gitHubArchive.ts:50-101`), falling back to `git clone --depth 1` (`src/core/git/gitCommand.ts:184`) on failure or for non-GitHub hosts (`remoteAction.ts:88-98`). Existence probed with `git ls-remote` HEAD-only first (`src/core/git/gitRemoteHandle.ts:11-26`). `FACT`

## 3. Strongest capabilities

- **Secret scanning on by default with a real rule preset**, covering files, git diffs, and git logs, with findings reported as counts only (`securityCheckWorker.ts:141`). No other tool in this group does this. `FACT`
- **A regression test that runs the whole pipeline against a planted secret.** `tests/core/security/securityScanSpec.test.ts` (158 lines) packs a fixture containing `FAKE_AWS_SECRET` (`:33-35`) end-to-end; the comment at `:24-31` says it exists specifically to stop performance optimisations from silently bypassing the scan. `FACT` — this is a good engineering instinct worth copying.
- **149 test files** (`find tests -name '*.test.ts' | wc -l`), including **21** covering the tree-sitter/compress path (one per grammar plus `parseFile.test.ts`, `parseFile.errorHandling.test.ts`, `LanguageParser.test.ts`) and **5** covering the security path. `FACT`
- **Eight MCP tools**, not just one packer (`src/mcp/mcpServer.ts:64-78`): `pack_codebase`, `pack_remote_repository`, `read_repomix_output`, `grep_repomix_output`, `file_system_read_file`, `file_system_read_directory`, `generate_skill`, `attach_packed_output` — i.e. it gives an agent a *searchable* handle to the packed output rather than dumping the whole thing into context. `FACT`
- **A `--sandbox [dir]` MCP mode** that confines tools to a workspace root and disables the remote-fetch, skill-generation, and attach tools (`cliRun.ts:199-201`, `mcpServer.ts:41-51`). `FACT`
- **Genuinely active**: 4,353 commits, 1,446 in the last 6 months, HEAD `c6f084be` dated 2026-08-03 — one day before this reading. `FACT`
- Optional git context in the artifact: `git.includeDiffs` and `git.includeLogs` with `includeLogsCount` default 50 (`configSchema.ts:153-155`). `FACT`

## 4. Critical weaknesses

- **Secrets in git diffs/logs are deliberately shipped.** `validateFileSafety.ts:10-12, 54-65`. If a user enables `--include-diffs` or `--include-logs` and a credential was committed, repomix warns and sends it anyway. This is the single most quotable defect in the tool and it is by design. `FACT`
- **Whole-file exclusion destroys context.** `filterOutUntrustedFiles.ts:4-8`. A config file with one API key is removed entirely, so the model loses the file's structure as well as the secret — and it is removed *silently* from the model's point of view (nothing in the output says "a file was withheld"). `FACT` Line-level redaction would preserve both safety and context.
- **No index, no incremental update, no staleness concept.** Every run re-walks, re-ignores, re-parses, re-scans. The only persistence is the content-hash token cache. Watch mode (`--watch`, `src/cli/actions/watch/`) triggers a **full re-pack** on any file change, not a patch. `FACT`
- **Compression is off by default** (`configSchema.ts:139`), so the default artifact is the full text of every file — the naive behaviour.
- **No cross-file or cross-repo relationships at all.** The tree-sitter pass extracts declarations per file; nothing links a call to its definition, and there is no graph, no ranking, no relevance ordering. Files come out in directory order. Compare `aider`, which uses the *same query lineage* to build a PageRank graph. `FACT` (absence: no graph/rank code anywhere under `src/core/`)
- **Quality is asserted, never measured.** There is no accuracy benchmark, no labelled dataset, no precision/recall figure for secret detection, and no evaluation of whether compressed output preserves enough to answer questions. Everything named `benchmark`/`bench` in the repo (`scripts/bench-cores.sh`, `.github/scripts/perf-benchmark/`, `.github/workflows/perf-benchmark.yml`, `npm run bench` → hyperfine, `package.json:37`) measures **wall-clock and memory only**. `FACT`
- **Dynamic dependencies are structurally out of scope** — no import resolution, no config parsing, no route/queue awareness. It is a formatter, not an analyser.
- **The hosted pack API is a bot-and-abuse problem the project has clearly hit**: `website/server/middlewares/` contains `rateLimit.ts`, `turnstile.ts`, `botGuard.ts`, `cloudflareGuard.ts`. `INFERENCE` from those file names — four layers of guard implies sustained abuse.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | No | No requirement artifact. `--instruction-file-path` (`cliRun.ts:126`) only pastes a user-written file into the output header. |
| Jira / work tracking | No | No tracker integration anywhere in `src/`. |
| Architecture / ADR | No | `output.directoryStructure` (`configSchema.ts:135`) emits a file tree. That is the whole of its architectural output. |
| Implementation | No | Produces input for a coding tool; writes no code and applies no edits. |
| PR review | Partial | `git.includeDiffs` puts working-tree and staged diffs into the artifact (`configSchema.ts:153`, `outputGenerate.ts:84-114`) — raw material for a review prompt, no review logic. |
| Test generation | No | Nothing. |
| Security / pentest | Partial | Secretlint scan of packed content (`src/core/security/`). This is egress hygiene for its own output, not application security — no SAST, no dependency scanning, no CVE awareness. |
| Release | No | Nothing. |
| Monitoring / incidents | No | Nothing. |
| Maintenance / knowledge | Partial | `--skill-generate` writes a Claude Agent Skill into `.claude/skills/<name>/` (`cliRun.ts:203-206`, `src/core/skill/`) — a generated, one-shot, unversioned repo primer with no staleness tracking. |

## 6. Security, deployment, and license

- **Deployment**: npm CLI (`bin/repomix.cjs` → `src/cli/cliRun.ts`), MCP stdio server (`--mcp`), Docker (`Dockerfile`), Nix flake (`flake.nix`), a hosted pack API (`website/server/`), and a WXT browser extension (`browser/`). Runs entirely locally by default; no auth, no tenancy — it is a user-level tool.
- **Secrets handling**: see §2/§4. On by default, whole-file exclusion, git diff/log exempt.
- **Network egress**: none in default local mode — repomix writes a file and does not call any model. Remote mode fetches `codeload.github.com` tarballs or shallow-clones. This is architecturally cleaner than any tool that calls an LLM itself: **the model call is the user's problem, so there is no API key to leak and no vendor to trust.** `INFERENCE` from the absence of any LLM client in `package.json:79-107`.
- **Prompt-injection surface**: the artifact is the payload. Repomix embeds arbitrary repo file contents (and, in MCP mode, hands them to an agent via `read_repomix_output`) with no sanitisation of instruction-shaped text. A `README.md` containing "ignore previous instructions" travels verbatim. The `--instruction-file-path` mechanism is an explicit, intended injection channel. `FACT` (no sanitiser exists under `src/core/output/`)
- **License**: MIT — `.spike/clones/repomix/LICENSE:1` "Copyright 2024 Kazuki Yamada"; `package.json:70` `"license": "MIT"`. `FACT` (verified by reading LICENSE) Fully permissive; the security module and tree-sitter query sets can be vendored. Note the query files themselves are credited to Aider/Cline (`src/core/treeSitter/queries/README.md:1-27`) and ultimately derive from tree-sitter grammar `tags.scm` files with their own upstream licenses — check those before vendoring. `INFERENCE`

## 7. Ideas to adopt or avoid

### Adopt

- **Secretlint as the pre-egress gate, on by default.** Specera should run `@secretlint/core` + the recommend preset over every chunk of repo content immediately before it enters a prompt, exactly as `securityCheckWorker.ts:119-151` does, in a worker pool so it does not serialise the pipeline. This is a maintained rule set Specera should not re-derive.
- **Never log the finding, only the count** (`securityCheckWorker.ts:141`). Specera's audit log must record "3 secrets suppressed in `src/config.ts`" and never the value — otherwise the audit log becomes the leak.
- **The planted-secret end-to-end regression test** (`tests/core/security/securityScanSpec.test.ts:24-35`). Specera should have exactly this test, with the same rationale comment: a fixture with a fake credential, run through the full pipeline, asserting it never appears in output. It is the only thing that stops a future perf optimisation from silently disabling the gate.
- **Content-addressed token cache keyed `${encoding}:${byteLength}:${hash}`** (`tokenCountCache.ts:327-331`). Cheap, correct, repo-independent, and it makes budget computation nearly free on re-runs. Copy the key format.
- **`grep_repomix_output` as an MCP tool** (`src/mcp/tools/grepRepomixOutputTool.ts:89`). Giving an agent a *searchable handle* to packed context instead of the packed context itself is the right primitive, and Specera should expose its index the same way.
- **`--sandbox [dir]` confinement for the MCP surface** (`mcpServer.ts:41-51`) — capability reduction by mode, with remote fetch and file-write tools disabled. Specera's MCP surface needs the same switch on day one.
- **Tree-sitter queries as data, credited upstream** (`src/core/treeSitter/queries/`, `queries/README.md`). Same query lineage as Aider; Specera should maintain one query set and use it for both trimming and graph extraction rather than two.

### Avoid

- **Exempting git diffs and logs from the secret gate** (`validateFileSafety.ts:10-12`). Specera must apply the gate uniformly to every content source, with no "but the user wanted it" carve-out.
- **Whole-file exclusion as the remediation** (`filterOutUntrustedFiles.ts:4-8`). Redact the matched span, keep the file, and emit a visible marker in the artifact so the model knows something was withheld.
- **Compression defaulting to off** (`configSchema.ts:139`). For a token-budgeted system the trimmed representation should be the default and the full text the opt-in.
- **Full rebuild on every watch event** (`src/cli/actions/watch/`). Specera's index must be incremental or it will not survive a monorepo.
- **Calling wall-clock benchmarking "benchmarking"** (`.github/workflows/perf-benchmark.yml`). Speed is not quality. Specera needs an accuracy eval or it has the same gap.

## 8. Build, borrow, buy, integrate, or reject

**Borrow** (with a live-integration option). MIT (`LICENSE:1`) allows lifting the security module wholesale, and the fastest correct move for Specera is to depend on `@secretlint/core` + `secretlint-rule-preset-recommend` directly and re-implement the worker-pool gate as line-level redaction rather than file exclusion. Do not adopt repomix as Specera's context layer: it is stateless, has no relevance ranking, no cross-file relationships, and no index, so it solves the "get bytes to a model" problem Specera has already moved past. Integrating the CLI as an optional export format ("give me this repo as one file") is cheap and defensible; building on it is not.

## 9. Evidence

- **HEAD read**: `c6f084be` — `git -C .spike/clones/repomix rev-parse --short HEAD`
- **Last commit**: `c6f084be 2026-08-03 Merge pull request #1771 from yamadashy/renovate/website-non-major-dependencies`
- **History**: 4,353 commits; first commit 2024-07-13; **1,446 commits in the last 6 months** — actively developed.
- **Version**: `repomix@1.17.0` (`package.json:2-3`).
- **License**: MIT — `.spike/clones/repomix/LICENSE:1`, "Copyright 2024 Kazuki Yamada"; corroborated `package.json:70`. Verified by reading the file.
- **Files read directly by me**: `src/core/security/filterOutUntrustedFiles.ts` (full), `src/core/security/validateFileSafety.ts` (full), `src/config/configSchema.ts:160-175`, `src/config/defaultIgnore.ts` (pattern count).
- **Files cited from delegated static reading** (paths + line numbers verified by that reader, spot-checked by me on the two security files above): `src/core/security/workers/securityCheckWorker.ts:12-64, 85-95, 119-151`; `src/core/security/securityCheck.ts:22-130`; `src/core/metrics/TokenCounter.ts`, `tokenEncodings.ts:3`, `calculateFileMetrics.ts:17-113`, `tokenCountCache.ts:21,68-80,262-293,327-352`; `src/core/treeSitter/languageConfig.ts:64-161`, `queries/queryTypescript.ts:1-73`, `queries/README.md:1-27`, `parseStrategies/BaseParseStrategy.ts:30-35`; `src/core/output/outputGenerate.ts:29-51, 84-114, 118-220`; `src/cli/cliRun.ts:75,126,142-143,161-167,179,184,198-206`; `src/mcp/mcpServer.ts:41-78`; `src/core/git/gitHubArchive.ts:50-101`, `gitCommand.ts:138-184`, `gitRemoteHandle.ts:11-26`; `src/cli/actions/remoteAction.ts:52-99, 218`.
- **Counts**: `find tests -name '*.test.ts' | wc -l` → 149; `tests/core/treeSitter/` → 21 test files; `tests/core/security/` → 5 test files; `grep -c "^  '" src/config/defaultIgnore.ts` → 86 default ignore patterns (verified by me).
- **Negative result — quality benchmark**: no `benchmark/` or `eval/` directory for output correctness. `scripts/bench-cores.sh`, `.github/scripts/perf-benchmark/`, `.github/workflows/perf-benchmark.yml`, and `npm run bench` (hyperfine, `package.json:37`) are wall-clock/memory only.
- **Commands run**: `git rev-parse`, `git log`, `ls`, `cat`, `sed -n`, `grep -c`, `find`. **No build, install, test suite, or repomix invocation was executed.**
