# Gitingest

A Python library + FastAPI web service that shallow-clones a git repo, applies a 138-pattern ignore list, and concatenates the surviving files into one text digest with a directory tree header and an aggregate token estimate.

## 1. Verdict

Irrelevant to Specera as a competitor, and a commodity within its own category. Read blunt: **gitingest's core digest is `cat` with an ignore list and a tree header** (`src/gitingest/output_formatter.py:27`) — no AST, no compression, no relevance ranking, no per-file token counts, one fixed output shape. The one thing it does better than `repomix` or `code2prompt` is being a *hosted service with an OpenAPI endpoint*: `POST /api/ingest` and `GET /api/{user}/{repository}` (`src/server/routers/ingest.py:22,55`) make repo→text a zero-install HTTP call, which is genuinely convenient. What kills it: it is dormant (last commit 2025-08-16, **zero commits in the last 6 months**), it does no secret detection whatsoever, and its hosted GET endpoint accepts a **GitHub personal access token as a URL query parameter** — a pattern that puts PATs into proxy logs, browser history, and referrer headers.

## 2. Core architecture and unique mechanism

There is no index and no analysis. The pipeline is: parse the query → shallow-clone → walk → filter → concatenate.

**Clone.** GitPython shallow clone with `--depth=1 --single-branch --no-checkout`, plus sparse/partial-clone when a subpath is requested (`src/gitingest/clone.py:92-111`, sparse path at `:99-104`), wrapped in `@async_timeout(DEFAULT_TIMEOUT)` = 60s (`clone.py:31`). `FACT`

**Filtering.** Three layers: a hardcoded `DEFAULT_IGNORE_PATTERNS` list of **138 patterns** (`src/gitingest/utils/ignore_patterns.py:7-168`), `.gitignore` + a project-specific `.gitingestignore` in git-wildmatch syntax including negation (`ignore_patterns.py:171-238`, wired at `src/gitingest/entrypoint.py:271`), and user include/exclude patterns. `include_gitignored` can force-include ignored files (`entrypoint.py:43,136`). `FACT`

**Hard resource caps** — the one place gitingest is more disciplined than its peers (`src/gitingest/config.py:6-10`, verified by reading): `FACT`
```
MAX_FILE_SIZE        = 10 MB    (per file)
MAX_DIRECTORY_DEPTH  = 20
MAX_FILES            = 10_000
MAX_TOTAL_SIZE_BYTES = 500 MB   (output cap)
DEFAULT_TIMEOUT      = 60 s     (clone)
```
Enforced during traversal in `src/gitingest/ingestion.py:234-320`, which raises once any cap is exceeded rather than silently truncating.

**Output.** One shape only: summary + directory tree + raw concatenated file contents, produced by `format_node` (`src/gitingest/output_formatter.py:27`). No JSON, no XML, no templating for the digest (Jinja2 is present but only renders the web UI's HTML, `src/server/server_config.py:8,56`). `FACT`

**Token counting.** `tiktoken` with a **single hardcoded encoding**, `o200k_base` (`output_formatter.py:196`, verified). Computed **once over the whole `tree + content` string** (`output_formatter.py:58`) — there are no per-file counts, so a caller cannot use it to make inclusion decisions. On a network failure fetching tiktoken's vocab, the estimate is silently dropped (`output_formatter.py:201-204`, verified). `FACT`

**The only file-aware processing** is `src/gitingest/utils/notebook.py` (159 lines), which flattens `.ipynb` JSON into a Python-script-shaped text, optionally stripping outputs. A format transform, not semantic extraction. `FACT`

**Server-side result cache (hosted only).** Digests are written to S3 keyed by `provider/owner/repo/commit/pattern-hash` (`src/server/s3_utils.py:60-118`, `generate_s3_file_path`) and checked before cloning (`src/server/query_processor.py:277-286`, `_check_s3_cache`). `FACT` **Note the key includes the commit SHA** — so the cache is correctly invalidated by a new commit, but there is no push trigger; freshness is pull-driven by whoever asks next.

## 3. Strongest capabilities

- **Explicit, enumerated resource caps** on file size, file count, depth, total output size, and clone time (`src/gitingest/config.py:6-10`) — enforced with a raise, not a truncate (`src/gitingest/ingestion.py:234-320`). `FACT` This is the one design decision here Specera should copy verbatim.
- **A documented HTTP API with an OpenAPI schema** (`GET /api`, `src/server/main.py:177-207`) and two ingest endpoints, rate-limited at `10/minute` per remote address via `slowapi` (`src/server/server_utils.py:5-15`, applied at `src/server/routers/ingest.py:23,56`). `FACT`
- **Commit-SHA-keyed result cache** on the hosted path (`src/server/s3_utils.py:60-118`) — the correct cache key, even though nothing triggers regeneration. `FACT`
- **Host-agnostic query parsing** — `tests/query_parser/test_git_host_agnostic.py` exists, so it is not GitHub-only. `FACT`
- **Core traversal and filtering are tested**: 11 test files / 2,229 lines, including `tests/test_ingestion.py::test_run_ingest_query` (`:22`) and `::test_include_ignore_patterns` (`:201`), plus dedicated `tests/test_gitignore_feature.py` and `tests/test_pattern_utils.py`. `FACT`
- MIT licensed (`LICENSE:3`). `FACT`

## 4. Critical weaknesses

- **Dormant.** Last commit `4e259a0` dated **2025-08-16**, and **0 commits in the 6 months to 2026-08-04** (`git log --since='6 months ago' --oneline | wc -l` → 0). Commit volume fell from 155/month (2024-12) to 16 (2025-08) and then stopped. `FACT`
- **No secret detection of any kind.** `grep -rni "secret\|redact\|credential" src/ --include=*.py` (run and verified) returns exactly four hits, all irrelevant: `src/gitingest/clone.py:90` logs the clone URL as the literal string `"<redacted>"`, and `src/server/s3_utils.py:44,138,143` handle gitingest's *own* AWS keys. The only protection is that `.env`/`venv` are in the ignore list (`src/gitingest/utils/ignore_patterns.py:112-117`). A hardcoded key in `config.py`, or a `.env.production` that does not match the `.env` pattern, ships to the model with no warning. `FACT`
- **GitHub PATs accepted as a URL query parameter.** `GET /api/{user}/{repository}?token=...` — `token: str = ""` at `src/server/routers/ingest.py:64`, documented in the endpoint docstring as *"GitHub personal access token for private repositories"* and forwarded at `:80` (verified by reading). Query strings land in reverse-proxy access logs, browser history, and `Referer` headers. The POST body path (`src/server/models.py:47,160`) types the token as a plain `str`, not a secret type. `FACT` — this is the single most serious finding in the file.
- **Aggregate-only token count** (`output_formatter.py:58`) means the number is a post-hoc report, not a budget mechanism. It cannot drive what to include.
- **No AST, no tree-sitter, no compression.** No `tree_sitter` dependency in `pyproject.toml` or anywhere in `src/`. The digest is full file text or nothing. `FACT`
- **No cross-file relationships, no ranking, no graph.** Files appear in traversal order. Nothing links a call to a definition; the repo boundary is the only boundary because there is nothing to cross it with.
- **Full rebuild every run** in the library; the only reuse is the hosted S3 cache. No local index, no incremental walk. `FACT`
- **Quality is unmeasured.** No benchmark, eval harness, or accuracy metric anywhere. The README's "quality & community" section (`README.md:12-17`) is CI/lint/OpenSSF-scorecard badges — process signals, not output quality. `FACT`
- **Telemetry on the hosted path**: Sentry with `send_default_pii` defaulting to `"true"` (`src/server/main.py:31-56`, specifically `:41`), and PostHog with a hardcoded project key `phc_9aNpiIVH2zfTWeY84vdTWxvrJRCQQhP5kcVDXUvcdou` at `src/static/js/posthog.js:72`, loaded on every page via `src/server/templates/base.jinja:69`. `FACT` The Sentry/PostHog code only runs in the server surface, not the CLI/SDK.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | No | Nothing. |
| Jira / work tracking | No | Nothing. |
| Architecture / ADR | No | Emits a directory tree in the digest header (`output_formatter.py:27`). That is all. |
| Implementation | No | Produces prompt input; writes no code. |
| PR review | No | No diff support at all — unlike `repomix` and `code2prompt`, there is no git-diff or git-log inclusion. |
| Test generation | No | Nothing. |
| Security / pentest | No | No scanning of any kind (§4). |
| Release | No | Nothing. |
| Monitoring / incidents | No | Prometheus counters (`src/server/metrics_server.py`, `src/server/routers/ingest.py:17`) monitor gitingest's own service, not the user's. |
| Maintenance / knowledge | No | The digest is a one-shot artifact with no persistence, versioning, or staleness concept in the library. |

## 6. Security, deployment, and license

- **Deployment**: pip package with a `gitingest` CLI script (`pyproject.toml:56-57`, entry `src/gitingest/__main__.py`); a Python SDK exporting `ingest` / `ingest_async` (`src/gitingest/__init__.py:3-4`); a self-hostable FastAPI app (`src/server/main.py`, `Dockerfile`, `compose.yml`); and the commercial hosted service at gitingest.com. **No MCP server** — `grep -rni "mcp\b"` across `src/`, `pyproject.toml`, `README.md`, `docs/` returns zero hits. `FACT`
- **Auth / tenancy**: none. The hosted API is unauthenticated, rate-limited to 10 req/min per IP (`src/server/server_utils.py:5-15`). There is no account model, so there is no tenancy isolation; the S3 cache is keyed by repo+commit+patterns, meaning **a cached digest of a private repo could in principle be served to a second caller who supplies the same repo path and pattern set** — I did not find a token check against the cache key. `UNVERIFIED` — verifying requires reading `_check_s3_cache` (`src/server/query_processor.py:277-286`) against the token-validation path (`:265-266, :294`) in full and confirming whether cache lookup precedes or follows token validation.
- **Secrets handling**: none for user code (§4). For the caller's own PAT, transmitted per-request and used transiently for cloning (`query_processor.py:294`); no evidence of server-side persistence, but the GET query-parameter path is a logging hazard.
- **Network egress**: git clone to the repo host; tiktoken vocab download on first use; on the hosted server, S3, Sentry, and PostHog.
- **Prompt-injection surface**: total. The digest is raw repo text destined for a prompt, with no sanitisation anywhere in `output_formatter.py`. `FACT`
- **SSRF**: the hosted service clones a user-supplied repo URL. Host parsing is in `src/gitingest/utils/` (`query_parser` tests confirm multi-host support); I did not audit the URL validation for internal-address rejection. `UNVERIFIED` — would need to read the host allowlist/validation in `src/gitingest/utils/git_utils.py` and `query_parser`.
- **License**: MIT — `.spike/clones/gitingest/LICENSE:3`, "Copyright (c) 2024 Romain Courtois". `FACT` (verified). Fully permissive. Note the repo is under the `coderamp-labs` GitHub org and `pyproject.toml:60` sets the homepage to `https://gitingest.com`, with `gitingest.com`/`*.gitingest.com` in the FastAPI allowed-hosts default (`src/server/main.py:88`) — this OSS repo is the codebase behind the commercial hosted product. `FACT` No copyleft or source-available friction; the license does not constrain reuse.

## 7. Ideas to adopt or avoid

### Adopt

- **The explicit resource-cap block** (`src/gitingest/config.py:6-10`). Five named constants — per-file bytes, file count, directory depth, total output bytes, clone timeout — enforced with a raise (`ingestion.py:234-320`). Specera's ingestion path needs exactly this, in one file, so limits are auditable rather than scattered.
- **Commit-SHA in the cache key** (`src/server/s3_utils.py:60-118`, `provider/owner/repo/commit/pattern-hash`). Specera should key every derived artifact — index shard, packed context, generated doc — on the commit it was derived from. Gitingest gets the key right and then does nothing with it; Specera should add the missing half (a push-triggered regeneration).
- **`.gitingestignore` as a tool-specific ignore file distinct from `.gitignore`** (`ignore_patterns.py:171-238`). A repo often wants "don't commit this" and "don't send this to a model" to be different sets. Specera should ship a `.speceraignore` with the same wildmatch+negation semantics.
- **Skip the token estimate rather than fail the request when the tokenizer is unavailable** (`output_formatter.py:201-204`). Degrade the metric, not the product.

### Avoid

- **Accepting credentials as URL query parameters** (`src/server/routers/ingest.py:64,80`). Specera must take tokens only in headers or POST bodies, and must type them as secrets so they cannot be logged accidentally.
- **Relying on ignore patterns as the secret defence** (`ignore_patterns.py:112-117`). `.env` in a denylist is not secret handling; it fails on any file not named `.env`.
- **A single hardcoded tokenizer encoding** (`output_formatter.py:196`). Specera targets multiple models; the encoding must be a parameter.
- **Aggregate-only token counts** (`output_formatter.py:58`). Counts must be per-file to be actionable.
- **`send_default_pii` defaulting to true in Sentry** (`src/server/main.py:41`) on a service that ingests private source code.

## 8. Build, borrow, buy, integrate, or reject

**Reject.** MIT permits reuse, but there is nothing here to reuse beyond the ~10-line resource-cap constants block and the cache-key shape, both of which are a morning's work. The product is `cat` plus an ignore list; it has no AST, no ranking, no per-file budgeting, no secret handling, no diff support, and no evaluation, and it has been dormant for a year (0 commits in 6 months, HEAD 2025-08-16). `repomix` supersedes it on every technical axis and is actively developed. If Specera ever wants a zero-install "repo as text" HTTP call, calling the hosted gitingest.com API is a legitimate stopgap — but not with a PAT, given `ingest.py:64`.

## 9. Evidence

- **HEAD read**: `4e259a0` — `git -C .spike/clones/gitingest rev-parse --short HEAD`
- **Last commit**: `4e259a0 2025-08-16 chore(deps): update github/codeql-action action to v3.29.9 (#501)`
- **History**: 405 commits total; first commit 2024-11-29; **0 commits in the last 6 months** (`git log --since='6 months ago' --oneline | wc -l` → 0).
- **License**: MIT — `.spike/clones/gitingest/LICENSE:3`, "Copyright (c) 2024 Romain Courtois". Verified by reading the file.
- **Files I read directly**: `src/server/routers/ingest.py:55-90` (PAT-in-query-parameter, verified verbatim); `src/gitingest/config.py:1-15` (resource caps, verified); `src/gitingest/output_formatter.py:190-206` (hardcoded `o200k_base`, verified); `grep -rni "secret\|redact\|credential" src/ --include=*.py` (negative result, verified — 4 irrelevant hits).
- **Paths cited from delegated static reading**: `src/gitingest/clone.py:31,90,92-111`; `src/gitingest/utils/ignore_patterns.py:7-168,112-117,171-238`; `src/gitingest/entrypoint.py:43,136,271`; `src/gitingest/ingestion.py:234-320`; `src/gitingest/output_formatter.py:9,27,58`; `src/gitingest/utils/notebook.py`; `src/gitingest/utils/auth.py:10-27`; `src/gitingest/__init__.py:3-4`; `src/server/main.py:31-56,88,177-207`; `src/server/models.py:47,160`; `src/server/routers/ingest.py:17,22-23`; `src/server/server_utils.py:5-15`; `src/server/server_config.py:8,13-14,56`; `src/server/s3_utils.py:25-27,44,60-118,138,143`; `src/server/query_processor.py:265-266,277-286,294`; `src/server/metrics_server.py`; `src/static/js/posthog.js:72`; `src/server/templates/base.jinja:69`; `pyproject.toml:56-57,60`.
- **Tests**: 11 files / 2,229 lines under `tests/`; core traversal covered by `tests/test_ingestion.py:22,201`, `tests/test_gitignore_feature.py`, `tests/test_pattern_utils.py`.
- **Negative results**: no `tree_sitter` dependency anywhere; no MCP (`grep -rni "mcp\b"` → 0 hits); no benchmark/eval harness.
- **Commands run**: `git rev-parse`, `git log`, `ls`, `sed -n`, `grep`, `find`, `wc -l`. **No build, install, test suite, server, or gitingest invocation was executed.**
