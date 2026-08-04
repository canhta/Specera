# GitDiagram

A single Next.js 16 app that fetches a GitHub repo's recursive tree and README (no file contents), asks a model for a prose architecture brief, then asks it for a Zod-schema-constrained graph AST, validates every node path against the real tree, retries on structural failure, and compiles the AST to Mermaid with a deterministic server-side compiler.

## 1. Verdict

Competitor by output, and the only tool in this set that **partially refutes** the "nobody grounds generated artifacts" hypothesis — so read this file before assuming the gap is uniform. It does four things none of its peers do: schema-constrained decoding via the OpenAI Responses API with a Zod format (`src/server/generate/openai.ts:382-388`), validation of every `node.path` against the actual repository tree (`src/server/generate/graph.ts:133-141`), a **deterministic AST→Mermaid compiler** so the model never emits diagram syntax (`graph.ts:379-473`), and a per-attempt audit record surfaced in the UI (`src/features/diagram/graph.ts:96-141`, `src/components/generation-audit-panel.tsx:68-73`). The refutation is narrow and it is worth being precise about the boundary: **it verifies that the things a node points at exist; it never verifies that any edge is real.** Edge validation is referential integrity between node ids only (`graph.ts:144-163`). No source file is ever read — `getGithubData` fetches the tree and the README and nothing else (`src/server/generate/github.ts:406`) — so every arrow in every diagram is an LLM inference from filenames and README prose, with zero import or call-graph evidence behind it. And there is no staleness concept at all: the artifact key is `public/v1/{owner}/{repo}.json` with no commit component (`src/server/storage/cache-key.ts:50`).

## 2. Core architecture and unique mechanism

Pipeline in `src/app/api/generate/stream/route.ts` (`runtime = "nodejs"`, `maxDuration = 300`), stages under `src/server/generate/`.

**Stage 0 — ingestion, bounded and fail-closed.** `github.ts`: default branch + `git/trees/{branch}?recursive=1` + `/readme`. `FACT` Hard limits: `MAX_INCLUDED_FILE_TREE_CHARACTERS = 780_000`, `MAX_README_BYTES = 750_000`, `GITHUB_REQUEST_TIMEOUT_MS = 30_000` (`github.ts:51-53`). **A truncated GitHub tree is rejected outright** (`github.ts:280`) rather than silently used — the opposite of the usual shortcut. Directory-segment and suffix exclusion lists plus a `.min.` infix filter trim the tree (`github.ts:82-122`). `FACT` **No blob is ever fetched.** `FACT` (verified: the only `api.github.com` calls are `/repos/{u}/{r}`, `/git/trees`, `/readme` — `github.ts:228, 256, 344`)

**Stage 1 — explanation.** `SYSTEM_FIRST_PROMPT` (`src/server/generate/prompts.ts:1-19`) receives `<file_tree>` and `<readme>`, asks for 5-8 sections under 650 words, and instructs: *"Ground every core component with 1-3 exact repo-relative paths copied from `<file_tree>` when available."* Streamed as SSE. `EXPLANATION_REASONING_EFFORT = "medium"` (`generation-policy.ts:1`). `FACT`

**Stage 2 — graph AST, schema-constrained.** `graph-planner.ts:74-249`. `SYSTEM_GRAPH_PROMPT` (`prompts.ts:21-51`). The Zod schema (`src/features/diagram/graph.ts:46-90`) is the contract and it is tight: `FACT`
- ids must match `/^[a-z][a-z0-9_]*$/` — the id space is disjoint from Mermaid syntax by construction.
- caps: `MAX_GRAPH_GROUPS = 10`, `MAX_GRAPH_NODES = 34`, `MAX_GRAPH_EDGES = 48`, label 72 chars, description 240, path 512.
- node shape is an enum of 6; edge style an enum of 2. Every field is required, nullable where optional.

Decoding is genuinely constrained, not prompted: `client.responses.parse({ text: { format: zodTextFormat(schema, schemaName) } })` (`openai.ts:382-388`). If the provider returns no `output_parsed`, it throws (`:394-396`); for OpenRouter it classifies a schema-capability rejection specifically (400/404/422 whose message matches `/structured outputs?|response_format|json_schema|text\.format/`) and **fails rather than degrading to loose JSON parsing** (`openai.ts:145-172, 401-408`). `FACT`

A detail that matters: **on attempt 1 the graph planner is not given the file tree** — the user prompt is `{ explanation }` only; `file_tree`, `previous_graph`, and `validation_feedback` are added only on retry (`graph-planner.ts:119-127`). The prompt therefore says *"On the first attempt, copy paths exactly from paths cited in `<explanation>`; otherwise use null"* (`prompts.ts:42`). Paths are laundered through a prose intermediate before they are checked. `FACT`

**Stage 3 — validation, the load-bearing mechanism.** `validateDiagramGraph` (`graph.ts:90-169`) emits typed issues in 8 categories (`graph.ts:18-26`): `schema_validation`, `invalid_json`, `duplicate_group_id`, `duplicate_node_id`, `unknown_group_id`, `missing_repository_path`, `unknown_edge_source`, `unknown_edge_target`. `FACT` The repository check is `if (node.path && !fileTreeLookup.has(node.path))` against a `Set` built from the real tree (`graph.ts:41-48, 133-141`). Failures are formatted into feedback and fed back to the model, up to `MAX_GRAPH_ATTEMPTS = 3` (`graph-planner.ts:87, 226-227`). `FACT`

**The deliberate hole in stage 3.** `isRepairableWithoutRetry` returns true when *every* issue is `missing_repository_path` (`graph.ts:202-209`); `stripUnknownNodePaths` then sets those paths to `null` and the graph is **accepted without a retry** (`graph-planner.ts:183-189`). The rationale is in the source: *"A path only drives a node's 'open on GitHub' link, so an unresolvable one is cosmetic"* (`graph.ts:177-181`). `FACT` The count is logged (`graph-planner.ts:209-218`) and stored as `strippedPathCount` in the attempt audit (`features/diagram/graph.ts:102-103`) — so the failure is *recorded*, which is more than any peer does, but the node itself survives in the diagram with its invented label and its invented edges intact.

**Stage 4 — deterministic compiler.** `compileDiagramGraph` (`graph.ts:379-473`) emits `flowchart TD`, subgraphs per group, `classDef` tone palette, and `click node_x "https://github.com/…"` lines built by `buildGitHubUrl` with `encodeURIComponent` on every segment (`:365-377`). Every piece of model text passes `escapeMermaidText` (`:211-236`), which entity-encodes `& # < > " \` \ | [ ] { } ( )` — with source comments explaining precisely why `#` and backtick must go (Mermaid decodes `#nn;` entities; a leading backtick turns the label into a markdown string and takes the whole diagram down). `FACT` **The model never emits Mermaid.** That is the single best structural decision in the repo.

**Stage 5 — client rendering, defence in depth.** `sanitizeMermaidSourceForRender` strips `%%{…}%%` config directives and any `click` line not matching `/^\s*click\s+[a-z_][a-z0-9_-]*\s+"https:\/\/github\.com\/[^"\s]+"\s*$/iu` (`src/features/diagram/mermaid-security.ts:1-33`) → Mermaid renders with `securityLevel: "antiscript"`, `htmlLabels: false` (`src/components/mermaid-diagram.tsx:96-101`) → SVG through DOMPurify (`:180`) → `enforceSafeMermaidLinks` walks every `<a>` and strips any href whose protocol ≠ `https:` or hostname ≠ `github.com` (`mermaid-security.ts:35-56`). `FACT` The GitHub-only allowlist is enforced **twice**, on source and on rendered DOM.

**Mermaid parsing is test-only.** `mermaid-validator.ts` (343 lines, JSDOM-backed) is exercised by `mermaid.test.ts` as a compiler contract test and is deliberately not imported into the production path. `FACT` That is: the guarantee "the compiler emits parseable Mermaid" is a CI property, not a runtime check.

**Persistence.** Artifact JSON in Cloudflare R2 at `public/v1/{owner}/{repo}.json`, or `private/v1/{hmac-sha256(CACHE_KEY_SECRET, pat)}/{owner}/{repo}.json` for private repos (`src/server/storage/cache-key.ts:40-70`). Upstash Redis for quota, cancellation, distributed locks. Newest-session-wins replacement under a distributed lock (`artifact-store.ts:26-96`).

## 3. Strongest capabilities

- **Model output constrained by a real schema at decode time, with no loose-parse fallback** (`openai.ts:382-396`, schema at `features/diagram/graph.ts:46-90`). Contrast `deepwiki-open`, which regexes XML out of free text and has a second regex fallback when that fails.
- **Every claimed repository path is checked against the real tree** (`graph.ts:41-48, 133-141`). This is the one true grounding check in either repo I read, and unlike `deepwiki-open`'s codemap it is a `Set.has` on the authoritative tree, not a substring search that can partially match.
- **Deterministic AST→Mermaid compiler with total escaping** (`graph.ts:211-236, 379-473`). Diagram syntax is never model output, so a prompt injection in a README cannot become a Mermaid directive.
- **Typed validation categories, counted and audited** (`graph.ts:18-26`; `graph-planner.ts:174-180` increments `validationCategoryCounts`; per-attempt `GraphAttemptAudit` with `rawOutput`, `validationFeedback`, `validationCategories`, `strippedPathCount` — `features/diagram/graph.ts:96-106`). The failure taxonomy is a first-class data type, not a log line.
- **The audit is user-visible.** `generation-audit-panel.tsx:68-73` renders `graphAttempts` as JSON in the UI. The user can see that attempt 1 failed validation and why.
- **Fail-closed ingestion**: truncated tree rejected (`github.ts:280`), oversized tree/README rejected (`:300, 356-377`), all before any model call — so cost is never spent on input that cannot produce a correct answer.
- **Serious security engineering for a hobby-scale app** (see §6), including a second, independent enforcement of the link allowlist on the rendered DOM.
- **414 test cases across 68 test files** (`find src -name '*.test.ts*' | wc -l` → 68; summed `it(`/`test(` → 414), including a 595-line `graph.test.ts` and a 479-line `github.test.ts`. `FACT`
- **Genuinely active**: 337 commits, **178 in the last six months**, HEAD `364d709` dated 2026-07-30. `FACT` (coordinator-verified)

## 4. Critical weaknesses

- **No source code is ever read.** `getGithubData` fetches metadata, tree, README (`github.ts:406`) — that is the complete input to both model stages. `FACT` So "architecture" is inferred entirely from **file and directory names plus README prose**. A repo whose layout misrepresents its runtime structure yields a confidently wrong diagram that passes every validation the system has.
- **Edges are never grounded.** Edge validation checks only that `edge.from`/`edge.to` are known node ids (`graph.ts:144-163`). `FACT` There is no import resolution, no call graph, no route/queue/DI awareness, nothing. The arrows — the entire semantic content of an architecture diagram — are free invention. This is the decisive finding: **path existence is verified; relationship existence is not, and cannot be, because no code was read.**
- **A verified path proves existence, not meaning.** `fileTreeLookup.has(node.path)` confirms `src/server/auth.ts` is a real file. It says nothing about whether the node labelled "Session Broker" corresponds to it. `INFERENCE` from `graph.ts:133-141` + the absence of any content check.
- **Hallucinated paths are silently repaired, not retried.** `isRepairableWithoutRetry` + `stripUnknownNodePaths` (`graph.ts:182-209`, applied at `graph-planner.ts:183-189`). A node that cited a nonexistent file keeps its label, its group, and its edges; only the hyperlink disappears. Nothing in the rendered diagram marks it. `FACT` The `strippedPathCount` reaches the audit panel, but not the diagram.
- **The first graph attempt does not see the file tree** (`graph-planner.ts:119-127`, `prompts.ts:42`). Paths are copied from prose written by a previous model call, so path errors are structurally likely on attempt 1 — which is presumably why the strip-and-accept path exists. `FACT`
- **No staleness detection whatsoever.** Artifact key is `public/v1/{owner}/{repo}.json` (`cache-key.ts:50`) — no commit SHA, no tree SHA, no branch. `FACT` (verified: `grep -rn "commit|sha|etag|stale"` over `src/server`, `src/features`, `src/app` returns only quota accounting, R2 ETags for storage, and GitHub conditional-request ETags — never artifact freshness.) `lastSuccessfulAt` (`artifact-store.ts:106`) is a wall-clock timestamp; the system cannot tell a one-hour-old diagram of unchanged code from a two-year-old diagram of a rewritten service. GitHub *does* return a tree SHA on the very request already being made (`github.ts:256`) — the invalidation key is in hand and unused. `INFERENCE` from those two facts.
- **Hard ceilings independent of repo size**: 34 nodes, 48 edges, 10 groups (`features/diagram/graph.ts:7-9`). `FACT` A 400-service monorepo and a 12-file utility both get at most 34 boxes; a large system is not summarised, it is truncated by a constant.
- **Quality is unmeasured.** 414 tests cover escaping, validation categories, SSE framing, quota arithmetic, cancellation, rate limiting, and the Mermaid-parses contract (`mermaid.test.ts:43-90`). `FACT` **None measure whether a produced diagram is a correct description of a repository.** There is no labelled dataset, no reference graph, no human-rated sample, no precision/recall on edges. The only "correctness" property tested is internal consistency.
- **Repo-boundary only.** Single GitHub repo per run. No cross-repo edges, no multi-repo systems, no non-GitHub hosts (`buildGitHubUrl` hardcodes `github.com`, `graph.ts:376`; the client allowlist hardcodes it again, `mermaid-security.ts:42`).
- **Regeneration is entirely manual.** No webhook, no scheduled refresh, no push trigger anywhere in `src/app/api/`. `FACT` (absence: no webhook route)

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | No | Nothing. |
| Jira / work tracking | No | Nothing. |
| Architecture / ADR | Partial | One `flowchart TD` per repo plus a ≤650-word prose brief (`prompts.ts:1-19`). No decision record, no alternatives, no rationale, no supersession, no revision binding — a picture, not an ADR. |
| Implementation | No | Writes no code. |
| PR review | No | No diff awareness; only a tree snapshot of the default branch (`github.ts:256`). |
| Test generation | No | Nothing. |
| Security / pentest | No | Nothing about the analysed repo. Its own posture is strong (§6) but that is not a product feature. |
| Release | No | Nothing. |
| Monitoring / incidents | Partial (self only) | `/api/healthz`, `readiness.ts`, PostHog + `web-vitals.tsx`, `scripts/check-performance-budgets.mjs` — monitoring of GitDiagram, not of the user's system. |
| Maintenance / knowledge | Partial | A browsable diagram catalog (`/browse`, `src/features/browse/`) with clickable nodes linking to real GitHub paths. Value decays silently because nothing tracks the commit it described. |

## 6. Security, deployment, and license

- **Deployment**: Vercel only for the live product (`vercel.json`, `next.config.js`); `Dockerfile` + `railway.json` are documented as a dormant recovery recipe (`docs/deployment-failover.md`). Cloudflare R2 for artifacts, Upstash Redis for coordination. Self-hostable — one app, `AI_PROVIDER` = `openai` | `openrouter` (`model-config.ts`).
- **Auth/tenancy**: no user accounts. A user's GitHub PAT travels per-request (`src/server/http/request-credentials.ts:29, 105`) and is **never persisted server-side**; instead it is HMAC-SHA256'd with `CACHE_KEY_SECRET` to derive a private storage namespace (`cache-key.ts:10-24`). An empty token throws rather than collapsing every caller into one shared namespace (`:15-20`) — a deliberate multi-tenancy footgun that was noticed and closed. `FACT`
- **CSRF/abuse**: mutating routes require same-origin (`src/server/http/same-origin.ts:50-69`, checking `Origin` and `Sec-Fetch-Site`). Per-IP fixed-window limiter then a daily complimentary token quota (`rate-limit.ts`, `complimentary-gate.ts`); callers using their own API key are exempt. The limiter **fails open on Redis errors** because the daily quota still bounds spend — a documented, reasoned trade-off. `client-ip.ts` is explicitly never an authentication signal.
- **Prompt-injection surface**: real but **structurally contained**, and this is the most transferable idea in the repo. The README is attacker-controlled and feeds stage 1 verbatim; a malicious README can absolutely steer node labels and edges. It cannot escape, because the model's output must satisfy a Zod schema whose ids are `/^[a-z][a-z0-9_]*$/`, all free text is entity-escaped by the compiler, diagram syntax is emitted by code rather than the model, and links are constrained to `github.com` at compile time and again at render time. `INFERENCE` from `graph.ts:211-236`, `mermaid-security.ts:1-56`, `mermaid-diagram.tsx:96-101`. The injection can lie; it cannot execute. **Compare `deepwiki-open`, where the same injection reaches a regex XML parser that will happily accept a `<page>` block from anywhere in the response.**
- **Secrets**: no scanning of repository content — but the attack surface is small because only the tree and README are read, never file contents. `INFERENCE` from `github.ts:406`.
- **Error redaction**: `redactUpstreamProviderTextForSharedRecord` scrubs raw provider error text before it is written to shared storage, since failure records are served to later visitors (`artifact-store.ts:52-59`). `FACT`
- **License**: MIT — `.spike/clones/gitdiagram/LICENSE:1-3`, "Copyright (c) 2024 Ahmed Khaleel". `FACT` (verified by reading the file) Fully permissive; the compiler, escaper, and validator can be vendored directly.

## 7. Ideas to adopt or avoid

### Adopt

- **Never let a model emit renderable syntax.** Model returns an AST; a deterministic compiler produces the artifact (`graph.ts:379-473`). Specera should apply this to every generated artifact with a grammar — Mermaid, Gherkin, OpenAPI, Terraform, SQL. It converts an entire class of injection and syntax-error bugs into a compiler bug you can unit-test once.
- **The escape function, verbatim.** `escapeMermaidText` (`graph.ts:211-236`) entity-encodes 14 characters and its comments document two non-obvious Mermaid failures (`#` re-decoding entity codes; a leading backtick converting the label into a markdown string that fails to lex and kills the whole diagram). Specera will hit both. Copy it, keep the comments.
- **Schema-constrained decoding with no loose-parse fallback** (`openai.ts:382-396`, and the OpenRouter capability check at `:145-172`). If the provider cannot honour the schema, fail — do not fall back to regexing JSON out of prose.
- **Validate every model-asserted identifier against the authoritative artifact, with typed failure categories** (`graph.ts:18-26, 90-169`). Specera should have exactly this shape: a `ValidationIssue { category, path, message }`, a category enum, counts per category on every generation, and the counts persisted with the artifact. It makes "how often does the model lie about X" a queryable number instead of a vibe.
- **Feed formatted validation feedback back as a bounded retry loop** (`graph-planner.ts:87, 226-227`, `MAX_GRAPH_ATTEMPTS = 3`), including the previous output and the specific issues. Cheaper and more reliable than a longer prompt.
- **Persist a per-attempt audit and show it to the user** (`features/diagram/graph.ts:96-141`, `generation-audit-panel.tsx:68-73`). Every Specera artifact should carry the attempt log, the validation categories hit, and the count of claims that failed grounding.
- **Reject truncated or oversized input before spending a model call** (`github.ts:280, 300, 356`). Fail-closed ingestion is both a cost control and a correctness control.
- **HMAC-derived per-credential storage namespace, throwing on an empty credential** (`cache-key.ts:10-24`). Specera needs this for any cached artifact derived from customer-scoped access.
- **Enforce the link allowlist twice — at compile time and on the rendered DOM** (`graph.ts:376`, `mermaid-security.ts:35-56`). Cheap defence in depth against a renderer that rewrites hrefs.

### Avoid

- **Treating a failed grounding check as cosmetic.** `graph.ts:177-181` + `graph-planner.ts:183-189`: a node whose path does not exist keeps its label and edges and loses only its link. Specera must treat a failed grounding as a claim-level defect — drop the node, or render it as explicitly unverified. A count in a collapsible audit panel is not user-visible provenance.
- **Grounding identifiers while leaving relationships free.** `graph.ts:144-163` validates edge endpoints, never edge existence. Specera's edges must come from parsed imports/calls/routes, with the model choosing *which* real edges to show and how to group them — not inventing them.
- **Deriving architecture from a file tree and a README** (`github.ts:406`, `prompts.ts:4`). This is the root cause of everything above.
- **Laundering paths through a prose intermediate** (`graph-planner.ts:119-127`, `prompts.ts:42`). Pass structured evidence directly to the stage that must cite it.
- **Fixed node/edge caps as the scaling strategy** (`features/diagram/graph.ts:7-9`). Specera needs hierarchical decomposition — drill-down levels — not a constant ceiling.
- **A cache key with no revision component** (`cache-key.ts:50`) when the tree SHA is already in the response you fetched (`github.ts:256`). Key artifacts by the SHA they describe; then "is this stale?" is one comparison, and regeneration can be automatic.
- **Calling a "does it parse" check validation** (`mermaid.test.ts:43-54`). Syntactic validity is a compiler contract, not a quality measure.

## 8. Build, borrow, buy, integrate, or reject

**Borrow, heavily.** MIT (`LICENSE:1`) permits lifting `escapeMermaidText`, `compileDiagramGraph`, `validateDiagramGraph`'s issue-category design, and the `mermaid-security.ts` allowlist pair — together roughly 400 lines that solve problems Specera will otherwise solve badly twice. Reject the product: its entire evidence base is a file tree and a README, so its diagram is a competently packaged guess, and it has no revision binding at all. The strategic reading for the spike is that GitDiagram proves grounding infrastructure is cheap and worth building — schema, validator, compiler, audit, retry — and simultaneously proves that grounding infrastructure over the wrong evidence base only makes an ungrounded artifact look trustworthy. Specera's differentiation is not "we validate"; GitDiagram validates. It is **validating edges against parsed code and binding every artifact to the commit it describes**, neither of which exists here.

## 9. Evidence

- **HEAD read**: `364d709` — last commit 2026-07-30 "style: format test files missed by pre-push gate"; 337 commits total, 178 in the last six months. (coordinator-verified)
- **License**: MIT, `.spike/clones/gitdiagram/LICENSE:1-3`, "Copyright (c) 2024 Ahmed Khaleel". Verified by reading the file.
- **Files read in full**: `src/server/generate/graph.ts` (473), `src/server/generate/graph-planner.ts` (249), `src/features/diagram/graph.ts` (141), `src/server/generate/prompts.ts` (51), `src/features/diagram/mermaid-security.ts` (56), `src/server/generate/generation-policy.ts` (8).
- **Files read in part**: `src/server/generate/openai.ts:140-175, 375-427`; `src/server/generate/github.ts` (constant + call-site listing, lines 16-406); `src/server/storage/cache-key.ts:1-80`; `src/server/storage/artifact-store.ts:1-110`; `src/server/generate/mermaid-validator.ts:1-60`; `src/app/api/generate/stream/route.ts` (pipeline call-site listing); `src/components/mermaid-diagram.tsx` (config grep); `src/server/http/same-origin.ts`, `request-credentials.ts` (greps); `README.md:1-60`.
- **Repo-authored docs consulted as claims, not evidence**: `README.md` "How generation works" and the checked-in `CLAUDE.md`. Both describe the pipeline accurately against the source I read; where this file states a mechanism it is cited to source, not to those docs. Treated as untrusted repo content per the spike rules.
- **Negative results (searches that returned nothing)**:
  - `grep -rn "commit|sha|etag|If-None-Match|regenerat|stale" --include=*.ts src/server src/features src/app` → no artifact revision binding; hits are quota accounting, R2 object ETags, and GitHub conditional-request ETags only.
  - No blob/content fetch: the only `api.github.com` endpoints are `/repos/{u}/{r}`, `/git/trees/{branch}?recursive=1`, `/readme` (`github.ts:228, 256, 344`).
  - No webhook or scheduled-regeneration route under `src/app/api/`.
  - No accuracy benchmark, eval harness, reference-graph fixture, or labelled dataset anywhere in the repo.
- **Test census**: `find src -name "*.test.ts*" | wc -l` → **68** files; summed `it(`/`test(` occurrences → **414** cases. Largest: `graph.test.ts` (595 lines), `github.test.ts` (479), `api.test.ts` (426), `mermaid.test.ts` (319). All measure mechanics, escaping, framing, and internal consistency; none measure diagram correctness against a repository.
- **Schema constants** (`src/features/diagram/graph.ts:7-14`): groups ≤10, nodes ≤34, edges ≤48, label ≤72, type ≤72, description ≤240, path ≤512, `MAX_GRAPH_ATTEMPTS = 3`.
- **Ingestion constants** (`src/server/generate/github.ts:51-53`): tree ≤780,000 chars, README ≤750,000 bytes, GitHub timeout 30 s.
- **Commands run**: `git log`, `find`, `wc -l`, `grep`, `sed -n`, `head`, `paste`, `bc`. **No `bun install`, build, dev server, or test suite was executed.**
