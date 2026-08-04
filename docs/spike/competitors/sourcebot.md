# Sourcebot

A self-hosted Next.js/Postgres/Redis application that mirrors repositories from seven code hosts, shells out to a forked `zoekt-git-index` per repo, and exposes zoekt search plus a tool-calling LLM agent ("Ask Sourcebot") over the resulting shards.

## 1. Verdict

`INFERENCE` (rests on §2, §4, §6): **the closest thing in this group to a product Specera competes with, and the one whose license makes reuse legally hazardous.** `FACT`: the non-`ee` code is **FSL-1.1-ALv2** (`LICENSE.md:7`), which explicitly forbids "making the Software available to others in a commercial product or service that … offers the same or substantially similar functionality" (`LICENSE.md:41-49`) — a code-intelligence platform is exactly the prohibited Competing Use. Everything under `ee/` and `packages/web/src/ee/` is under a separate proprietary Enterprise License requiring paid seats (`ee/LICENSE:6-15`), and that is where code navigation, the chat agent, MCP, SSO, and audit live (`packages/shared/src/entitlements.ts:42-55`). Its one genuinely strong idea is architectural: it built the agentic layer on **verifiable primitives** — an LLM with `grep`, `glob`, `readFile`, `listTree`, `listCommits`, `getDiff` tools over a zoekt index, so every answer carries a citation to a real byte range. What kills it technically: `FACT` — its advertised "IDE-level code navigation (goto definition and find references)" is a **regex search for `\bsymbolName\b`** (`packages/web/src/features/codeNav/api.ts:26-32`, `:83-91`), not symbol resolution; and freshness is a 1-hour poll (`packages/shared/src/constants.ts:22`) followed by a full zoekt repo rebuild.

## 2. Core architecture and unique mechanism

`FACT` **zoekt is a forked git submodule, driven by shelling out.** `.gitmodules` declares `vendor/zoekt` → `https://github.com/sourcebot-dev/zoekt`, branch `main` — a Sourcebot fork of Sourcegraph's zoekt, not upstream. `packages/backend/src/zoekt.ts:11-53` builds an argv and calls `execFile('zoekt-git-index', args)` with: `-allow_missing_branches`, `-index INDEX_CACHE_DIR`, `-max_trigram_count`, `-file_limit`, `-branches <revisions>`, `-tenant_id <orgId>`, `-repo_id <id>`, `-shard_prefix_override`, and `-large_file` globs. `FACT`: **`-delta` is not passed**, so zoekt's file-granular delta-shard path (see `zoekt.md` §2) is never used — every re-index of a changed repo is a full shard rebuild. `-tenant_id` and `-repo_id` are fork-only flags not present in upstream zoekt's `cmd/zoekt-git-index/main.go`; `INFERENCE`: multi-tenancy is implemented *inside the fork's index format*, which is why the fork exists.

`FACT` **Search results reach the web tier over gRPC/protobuf.** `packages/web/src/proto/zoekt/webserver/v1/` contains generated TypeScript for `StreamSearchResponse`, `LineMatch`, `LineFragmentMatch`, `Symbol`, `SymbolInfo`, `Stats`, `RepositoryBranch`, `IndexMetadata`, `Language`, `RepoRegexp` — i.e. Sourcebot talks to `zoekt-webserver`'s streaming gRPC API rather than parsing CLI output.

`FACT` **Code navigation is text search wearing a symbol costume.** `findSearchBasedSymbolReferences` (`packages/web/src/features/codeNav/api.ts:16-64`) constructs a zoekt query IR of `AND[ regexp:"\bNAME\b" (case_sensitive, content) , branch:REV , language-filter? , repo-filter? ]` capped at `MAX_REFERENCE_COUNT = 1000` (`:13`). `findSearchBasedSymbolDefinitions` (`:68-124`) is the same query wrapped in zoekt's `symbol:` operator, which restricts matches to ctags-derived symbol ranges. `FACT`: `grep -rn "scip\|lsif" packages/ ee/` returns **nothing** — there is no SCIP/LSIF ingestion, no language server, and no compiler anywhere in the tree.

`FACT` **The agent's tool surface is deliberately primitive and verifiable.** `packages/web/src/features/tools/`: `grep.ts`, `glob.ts`, `readFile.ts`, `listTree.ts`, `listRepos.ts`, `listCommits.ts`, `getDiff.ts`, `findSymbolDefinitions.ts`, `findSymbolReferences.ts` — each paired with a `.txt` file holding its prompt description. `packages/web/src/ee/features/chat/tools/` adds `loadSkillTool.ts` and `toolRequestActivation.ts`. `skills/codebase-guide.md` is a markdown "skill" loaded on demand. `INFERENCE`: the model never sees an embedding or a similarity score; it composes exact-match queries and reads real files, so every citation is checkable.

`FACT` **Model-provider-agnostic.** `packages/web/package.json:19-31,173` depends on `@ai-sdk/{amazon-bedrock,anthropic,azure,deepseek,google,google-vertex,mistral,openai,openai-compatible,xai}`, `@ai-sdk/mcp`, `@anthropic-ai/sdk`, and `openai`. `INFERENCE`: a self-hoster can point it at a private Bedrock/Azure endpoint, so "self-hosted" is not undermined by a hardcoded model vendor.

`FACT` **Indexing scheduler**: `packages/backend/src/repoIndexManager.ts:100-172` runs `setIntervalAsync` every `reindexRepoPollingIntervalMs` (default **1 second**, `packages/shared/src/constants.ts:25`) to schedule jobs, but only enqueues a repo whose last index is older than `reindexIntervalMs` (default **1 hour**, `constants.ts:22`). `resyncConnectionPollingIntervalMs` is 1 second (`constants.ts:24`). `INFERENCE`: worst-case staleness after a push is ~1 hour plus a full zoekt repo rebuild.

`FACT` **Code hosts**: `packages/backend/src/` has dedicated connectors for `github.ts`, `gitlab.ts`, `bitbucket.ts`, `gitea.ts`, `gerrit.ts`, `azuredevops.ts`, and generic `git.ts` — seven, the broadest host coverage in this group.

`FACT` **Deployment**: `docker-compose.yml` — one `sourcebot` image plus Postgres 16 and Redis 8, with named volumes for data, DB, and Redis.

## 3. Strongest capabilities

- `FACT` **Agentic retrieval over exact primitives, not embeddings.** `packages/web/src/features/tools/{grep,glob,readFile,listTree,getDiff,listCommits}.ts` — the LLM does the semantic work (query formulation, iteration) while the index does only exact matching. `INFERENCE`: this sidesteps the entire embedding-recall problem that claude-context measured at F1 parity with grep, and it makes every answer auditable.
- `FACT` **Prompt text is a first-class, reviewable artifact.** Each tool has a sibling `.txt` (`findSymbolReferences.txt`, `grep.txt`, `getDiff.txt`, …) rather than inline string literals — prompts are diffable and reviewable in PRs.
- `FACT` **Cryptographically signed offline licensing.** `packages/shared/src/entitlements.ts:15-25` defines an `sourcebot_ee_`-prefixed offline license payload (`id`, `seats`, `anonymousAccess`, `expiryDate`, `sig`) verified against the Ed25519 public key committed at `public.pem`, plus an online-assertion path (`:63-90`) with a 5-minute clock-skew allowance (`:37`). Twelve named entitlements gate features (`:42-55`): `search-contexts`, `sso`, `code-nav`, `audit`, `analytics`, `permission-syncing`, `github-app`, `org-management`, `oauth`, `ask`, `mcp`, `scim`.
- `FACT` **Enterprise controls exist and are separated**: `packages/web/src/ee/features/{sso,scim,oauth,audit,analytics,membership,mcp}` — SCIM provisioning and audit logging are present, which most tools in this group lack entirely.
- `FACT` **Multi-tenancy is pushed down into the index**, via `-tenant_id` on `zoekt-git-index` (`packages/backend/src/zoekt.ts:22`) — tenant isolation is an index-level filter, not an application-level `WHERE` clause.
- `FACT` **Actively developed at high velocity**: 1,358 commits, **553 in the last 6 months**, HEAD `97ebcd63` dated 2026-08-03; the head commit is a CVE remediation (`chore: upgrade golang.org/x/text to v0.39.0 to address CVE-2026-56852`). 112 `*.test.ts(x)` files.
- `FACT` **Failure cleanup is explicit**: `cleanupTempShards` (`packages/backend/src/zoekt.ts:64-88`) removes `.tmp` shard files left by an interrupted index run — the kind of operational detail most competitors here omit.

## 4. Critical weaknesses

- `FACT` **"Goto definition and find references" is `\bNAME\b` regex matching.** `packages/web/src/features/codeNav/api.ts:26-32` and `:83-91`. `INFERENCE`: this cannot distinguish two same-named methods on different types, cannot follow an interface to its implementations, returns every comment and string literal containing the token for the references case, and is silently wrong in exactly the situations where a developer needs it. The README's claim "IDE-level code navigation … across all your repos" (`README.md:64`) is a `VENDOR CLAIM` contradicted by the implementation.
- `FACT` **References are truncated at 1,000 matches** (`packages/web/src/features/codeNav/api.ts:13`, `MAX_REFERENCE_COUNT`). `INFERENCE`: for any widely-used symbol the "find references" answer is a silently incomplete prefix, and there is no signal in the response type that truncation occurred beyond a raw `matchCount`.
- `FACT` **Zoekt's delta path is unused.** `packages/backend/src/zoekt.ts:17-28` never passes `-delta`. Combined with `reindexIntervalMs = 1 hour` (`packages/shared/src/constants.ts:22`), the freshness answer is: **up to an hour of staleness, then a full repository re-index** — not seconds, not per-file. This is the single hardest technical weakness for a tool positioned on "understand your codebase".
- `FACT` **No cross-repository or cross-service edges.** The unit of everything — index shard, tenant scoping, repo filter (`codeNav/api.ts:44-48`) — is the repository. Nothing models a call from service A to service B, a queue topic, a DI binding, or config-driven wiring; the index is text and ctags symbol ranges only.
- `FACT` **No evaluation of any kind.** `find . -iname '*eval*' -o -iname '*benchmark*'` (excluding `node_modules`) returns **zero results** across a 1,358-commit repository that ships an LLM answering questions about code. There is no retrieval-quality measurement, no answer-correctness harness, and no regression suite for the agent. `INFERENCE`: "Ask Sourcebot" quality is unmeasured by its authors and cannot be compared to anything.
- `FACT` **A forked zoekt is a permanent maintenance tax.** `vendor/zoekt` points at `sourcebot-dev/zoekt`, and fork-only flags (`-tenant_id`, `-repo_id`, `-shard_prefix_override`) are load-bearing (`packages/backend/src/zoekt.ts:22-25`). `INFERENCE`: upstream zoekt improvements — notably delta shards — arrive only via merges Sourcebot performs.
- `FACT` **Prompt-injection surface is wide and unmitigated.** The agent reads repository content through `readFile`/`grep`/`getDiff` and re-feeds it to a model that holds tool-calling capability, and `loadSkillTool.ts` loads markdown "skills" (`skills/codebase-guide.md`) as instructions. `INFERENCE`: a crafted file or commit message in an indexed repo is a direct instruction channel to the agent; no sanitisation layer exists between tool output and the model.
- `FACT` **Heavy operational footprint** for what is fundamentally a search index: Next.js web app + Postgres + Redis + supervisord + the zoekt binaries (`docker-compose.yml`, `supervisord.conf`, `Dockerfile`), plus PostHog telemetry (`packages/backend/src/posthog.ts`, `posthogEvents.ts`) and Grafana Alloy config (`grafana.alloy`).

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No such concept in `packages/` or `ee/` |
| Jira/work tracking | No | Connectors are code hosts only (`packages/backend/src/{github,gitlab,bitbucket,gitea,gerrit,azuredevops}.ts`); no issue-tracker integration |
| Architecture/ADR | No | No structural model; ctags symbol ranges are used for `symbol:` filtering (`codeNav/api.ts:83-91`), nothing more |
| Implementation | No | Read-only. The agent's tools (`packages/web/src/features/tools/`) contain no write or edit capability |
| PR review | Partial | `getDiff.ts` and `listCommits.ts` give the agent commit and diff access, so it can answer questions *about* a change — but there is no review workflow, no PR object, and no comment posting |
| Test generation | No | Nothing in the tree |
| Security/pentest | No | Nothing in the tree. `trivy.yaml` and `.github/workflows/license-audit.yml` scan Sourcebot itself, not the indexed code |
| Release | No | Nothing in the tree |
| Monitoring/incidents | No | `grafana.alloy`, `promClient.ts`, `instrument.ts` monitor Sourcebot's own health, not the user's systems |
| Maintenance/knowledge | Yes | This is the product: cross-repo, cross-branch search plus an agent that answers codebase questions with inline citations (`README.md:40-56`), backed by `skills/codebase-guide.md` |

## 6. Security, deployment, and license

`FACT` **License is split and both halves restrict reuse — this is the decisive fact about Sourcebot.**
- `LICENSE.md:1-7`: "Copyright (c) 2026 Taqla Inc." Content in any folder named `ee` is under `ee/LICENSE`; everything else is under the **Functional Source License, Version 1.1, ALv2 Future License (FSL-1.1-ALv2)**.
- FSL grants use "for any Permitted Purpose", where **"A Competing Use means making the Software available to others in a commercial product or service that: (1) substitutes for the Software; (2) substitutes for any other product or service we offer using the Software …; or (3) offers the same or substantially similar functionality as the Software"** (`LICENSE.md:41-49`). Permitted Purposes are internal use, non-commercial education, non-commercial research, and professional services *to a Sourcebot licensee* (`LICENSE.md:51-61`).
- `LICENSE.md:99-104`: the FSL converts to **Apache 2.0 on the second anniversary** of each version's release. So Sourcebot code from ≥2 years ago is Apache-2.0 today; current code is not.
- `ee/LICENSE:6-15` (Sourcebot Enterprise License): the `ee` code "may only be used for internal business purposes if you … have a valid Sourcebot Enterprise license for the correct number of user seats", modifications and patches vest in Sourcebot, and "it is forbidden to copy, merge, publish, distribute, sublicense, and/or sell the Software."

`INFERENCE` (from `LICENSE.md:41-49` + the fact that Specera is a commercial code-intelligence platform): **Specera cannot copy, fork, vendor, or link current Sourcebot code — at all.** Building a competing product is the paradigm Competing Use the FSL is written to prohibit, and Permitted-Purpose "internal use" does not extend to shipping. Reuse is limited to (a) running an unmodified instance internally, (b) reading it for design ideas expressed independently, or (c) using code whose version is more than two years old under the Apache conversion — which excludes essentially all of the agent, code-nav, and multi-tenancy work. The `ee/` half is worse: seat-licensed proprietary, with an assignment-of-modifications clause.

`FACT` **Deployment: self-host only, Docker Compose.** `docker-compose.yml` runs `docker.sourcebot.dev/sourcebot-dev/sourcebot:latest` + Postgres 16 + Redis 8. A hosted demo exists at `app.sourcebot.dev` (`README.md:15`), and `fly.toml` is present, but self-hosting is the documented path.

`FACT` **Auth and tenancy**: `withOptionalAuth` middleware wraps code-nav actions (`packages/web/src/features/codeNav/api.ts:17`), and `packages/web/src/ee/features/{sso,oauth,scim,membership,audit}` supply enterprise identity — all gated behind license entitlements (`packages/shared/src/entitlements.ts:42-55`). `INFERENCE`: on the free tier, SSO, permission syncing, audit, code-nav, and the chat agent are all unavailable, so the FSL-licensed portion alone is a search UI.

`FACT` **Egress**: repository content goes to whichever LLM provider is configured (`packages/web/package.json:19-31`); PostHog analytics (`packages/backend/src/posthog.ts`, `packages/web/src/lib/posthogEvents.ts`) and a "lighthouse" online-license callback (`packages/shared/src/lighthouseTypes.ts`, `entitlements.ts:63-90`) both phone home by default.

`FACT` **Secrets**: code-host tokens are handled by the connection managers (`packages/backend/src/connectionManager.ts`, `connectionUtils.ts`); the license verification public key is committed in the clear at `public.pem` (Ed25519), which is correct — it is a *public* key.

## 7. Ideas to adopt or avoid

*(Adopt = re-implement the idea independently. Given `LICENSE.md:41-49`, Specera must not copy Sourcebot code; these are design patterns, not code lifts.)*

### Adopt

- **Give the agent exact primitives, not a similarity score.** The tool set `grep / glob / readFile / listTree / listCommits / getDiff / findSymbolDefinitions / findSymbolReferences` (`packages/web/src/features/tools/`) lets the LLM iterate on precise queries and cite byte ranges. Specera should expose the same shape — a fast exact index plus file/tree/history readers — and let the model supply semantics, because this is the only architecture in this group where an answer is checkable.
- **Store prompts as separate reviewable files** (`findSymbolReferences.txt`, `grep.txt`, …) rather than string literals. Specera's prompts will change more often than its code and must be diffable, ownable, and revertible independently.
- **Push tenant identity into the index, not the query filter.** `-tenant_id` on the indexer (`packages/backend/src/zoekt.ts:22`) means a cross-tenant leak requires an index-level bug rather than a forgotten `WHERE` clause. Specera should make tenant a mandatory index-resident dimension from the first commit.
- **Two-timer scheduling: fast poll, slow threshold.** `repoIndexManager.ts:100-110` polls every second but only enqueues repos past `reindexIntervalMs`, and explicitly guards against re-enqueuing repos with recent failed or stuck jobs (`:132-151`). Specera should copy the *guard* logic — recent-failure and stuck-job suppression are the parts that keep an indexing fleet from thrashing.
- **Signed offline license entitlements as a capability list** (`packages/shared/src/entitlements.ts:15-55`) — a clean pattern if Specera ever needs air-gapped licensing.

### Avoid

- **Calling regex "code navigation."** `codeNav/api.ts:26-32` markets `\bNAME\b` as goto-definition/find-references. Specera should either use real symbol resolution (see `serena.md` — LSP-backed, MIT) or label search-based navigation honestly as "textual occurrences", with a visible completeness caveat.
- **Silently truncating references at a constant** (`codeNav/api.ts:13`, 1000). If a result set is capped, the caller and the model must be told.
- **Hour-scale reindex intervals with full rebuilds** (`constants.ts:22` + no `-delta` in `zoekt.ts:17-28`). Specera's freshness target should be commit-triggered and file-granular; this is the clearest place to beat an incumbent.
- **Forking your index engine.** `vendor/zoekt` → `sourcebot-dev/zoekt` permanently detaches Sourcebot from upstream improvements. If Specera needs tenant IDs in zoekt, prefer shard-prefix/naming conventions and a filter layer over a format fork.
- **Shipping an LLM code-answering product with no evaluation harness** — zero eval/benchmark files across 1,358 commits.

## 8. Build, borrow, buy, integrate, or reject

**REJECT (license-forced).** This is not a technical judgement. FSL-1.1-ALv2 (`LICENSE.md:7`, `:41-49`) prohibits making the software available in "a commercial product or service that … offers the same or substantially similar functionality", which is precisely what Specera is; the `ee/` half is seat-licensed proprietary with an assignment-of-modifications clause (`ee/LICENSE:6-15`). `INFERENCE`: Specera must not vendor, fork, link, or copy any current Sourcebot code, and engineers should be instructed not to read `ee/` at all before writing equivalent features. What Specera *can* do is run an instance internally under the Permitted-Purpose "internal use" grant to study behaviour, and reach independently for the same open components underneath — zoekt is Apache 2.0 upstream (see `zoekt.md`) and is where the actual retrieval value lives. The two-year Apache conversion (`LICENSE.md:99-104`) does not help: the agent, code-nav, and tenancy code is all recent.

## 9. Evidence

- Commit read: `97ebcd63` — `git -C .spike/clones/sourcebot rev-parse --short HEAD`
- Last commit: `97ebcd63 2026-08-03 chore: upgrade golang.org/x/text to v0.39.0 to address CVE-2026-56852 (#1535)`
- History: 1,358 commits; first commit `b43aa468 2024-08-23`; 858 in the last 12 months; **553 in the last 6 months**. Highest velocity in this competitor group.
- Licenses: `LICENSE.md:1-7` (split declaration), `LICENSE.md:16` (FSL-1.1-ALv2, Taqla Inc. 2026), `LICENSE.md:41-49` (Competing Use definition), `LICENSE.md:51-61` (Permitted Purposes), `LICENSE.md:99-104` (Apache 2.0 conversion at 2 years); `ee/LICENSE:1-15` (Sourcebot Enterprise License, seat-based, no redistribution).
- Key files read: `packages/backend/src/zoekt.ts` (indexer invocation + temp-shard cleanup), `packages/backend/src/repoIndexManager.ts:44-172` (scheduler), `packages/shared/src/constants.ts:22-25` (intervals), `packages/shared/src/entitlements.ts:15-90` (licensing + entitlement list), `packages/web/src/features/codeNav/api.ts` (search-based nav), `packages/web/src/features/tools/` (agent tool set), `packages/web/src/ee/features/` (EE feature list), `packages/web/package.json:19-31` (model providers), `.gitmodules`, `docker-compose.yml`, `README.md`, `skills/codebase-guide.md`.
- Defaults recorded: `reindexIntervalMs = 3600000` (1 hour), `reindexRepoPollingIntervalMs = 1000`, `resyncConnectionPollingIntervalMs = 1000` (`packages/shared/src/constants.ts:22-25`); `MAX_REFERENCE_COUNT = 1000` (`packages/web/src/features/codeNav/api.ts:13`).
- Negative findings (searches that returned nothing): `grep -rn "scip\|lsif\|SCIP\|LSIF" packages/ ee/` → no results (no precise code intelligence); `find . -iname '*eval*' -o -iname '*benchmark*'` excluding `node_modules` → no results (no evaluation harness).
- Test surface: 112 `*.test.ts`/`*.test.tsx` files across `packages/` and `ee/`.
- Commands run (all read-only): `git rev-parse`, `git log`, `ls`, `find`, `grep`, `sed -n`/`head` on sources and license files. No `yarn install`, build, Docker Compose start, or test run was performed. `vendor/zoekt` is an uninitialised submodule in this clone, so the fork's own source was not read — see `zoekt.md` for upstream.
- `UNVERIFIED`: what exactly the `sourcebot-dev/zoekt` fork changes beyond `-tenant_id`/`-repo_id`/`-shard_prefix_override`. Verifiable by diffing `github.com/sourcebot-dev/zoekt` against `github.com/sourcegraph/zoekt`.
