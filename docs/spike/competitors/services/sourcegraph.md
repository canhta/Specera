# Sourcegraph

A trigram-indexed code search engine for large multi-repo codebases, now sold only as a single enterprise contract that bundles Code Search, an agentic search product (Deep Search), and a cross-repo change-execution engine (Batch Changes).

## 1. Verdict

Competitor to Specera's *implementation* and *maintenance* legs only, but the most credible one in this file set: it is the only vendor here with 13 years of large-enterprise deployment, five GCP data-residency regions, and a mechanism (Batch Changes) that actually lands merged PRs across thousands of repositories. `INFERENCE` The single thing it does better than anything else is **cross-repository mechanical change at fleet scale with per-changeset review tracking** — the batch spec + changeset reconciliation loop, evidenced in the Batch Changes docs. What kills it as a Specera substitute: it has no requirements, Jira, ADR, test-generation, release, or incident surface at all, and its own homepage no longer lists Cody, so the AI layer is being re-pointed at *other people's agents* (Claude Code, Codex, MCP) rather than owning the SDLC. `FACT` Sourcegraph also stopped being open source: the core repo was relicensed to a proprietary Enterprise license on 2023-06-13 and made private on 2024-08-22 — so there is nothing to borrow except `zoekt`.

## 2. Core architecture and unique mechanism

**Search index (the real mechanism).** `FACT` Sourcegraph runs `zoekt` to build a **trigram index of the default branch of every repository**; queries against non-default branches or not-yet-indexed code fall through to a separate `searcher` service that greps on demand. The docs state this is a deliberate space/latency tradeoff: "balances optimizing the common case (searching all default branches) with space savings (not indexing everything)" (https://sourcegraph.com/docs/admin/architecture, fetched 2026-08-04).

**Named services in the documented architecture** `FACT` (same URL): `zoekt` (trigram indexing), `searcher` (non-indexed search), `gitserver` ("the sharded service that stores repositories and makes them accessible to other Sourcegraph services"), `worker` (repo update/metadata sync, permissions sync, telemetry), `frontend` (GraphQL API), Postgres (repo metadata + permissions), and a separate `codeinsights-db`.

**Relationship to zoekt** `FACT`: `zoekt` originated at Google (`google/zoekt`, archived 2024-01-16, last push 2024-01-16). Sourcegraph now maintains the live fork `sourcegraph/zoekt` — Apache-2.0, 1,806 stars, last push 2026-07-29 (GitHub API, 2026-08-04). This is the only meaningful open-source artifact Sourcegraph still ships. `INFERENCE` Because zoekt is a trigram index over text, Sourcegraph's base retrieval is **lexical, not graph** — it is not a code-property-graph product, whatever the marketing word "code graph" on the MCP tile implies.

**Deep Search (the agentic layer).** `FACT` Deep Search is "an agentic code search tool that understands natural language questions about your codebase." It runs an agentic loop: "The AI agent can intelligently use tools to explore the codebase. In each loop iteration, the agent gradually refines its understanding of the question and codebase, searching until it is confident in its answer." Its tools are "multiple modes of Sourcegraph's Code Search and Code Navigation features." Crucially for a security review: "All processing occurs within your Sourcegraph instance, with only external calls made to the configured LLM." Requests may stay open up to 5 minutes; self-hosted instances need a 5-minute proxy timeout. Not supported for BYOK customers. (https://sourcegraph.com/docs/deep-search, fetched 2026-08-04)

**Batch Changes (the change-execution engine).** `FACT` A batch change starts from "a YAML file that defines a batch change, including target repositories, commands to execute, and templates" for changesets and commits. A code-search query selects repositories; commands run per repository and emit **changeset specs** (diff + commit message + title + body); a `batch-changes-controller` then reconciles code-host state against that desired intent, opening PRs / MRs / Gerrit changes and tracking their checks and review status through merge, with a burndown chart. Code hosts: GitHub, GitLab, Bitbucket variants, Gerrit, Perforce (beta). Enterprise plans only. (https://sourcegraph.com/docs/batch-changes, fetched 2026-08-04)

**Agentic Batch Changes** `VENDOR CLAIM` (public beta, announced ~2026-07-08 via press release syndication): from a single prompt, the agent "uses Sourcegraph search and Deep Search to identify repositories that need the change, validates its approach in an initial repository, then expands the rollout," reacts to CI signals, and iterates on failures. The routing detail is the interesting part: "for deterministic changes, it can write a script or entire program to efficiently apply changes, and for changes requiring additional judgment per repository, it can delegate to **Claude Code or Codex** with detailed instructions." (https://cioinfluence.com/machine-learning/sourcegraph-launches-agentic-batch-changes-in-public-beta-bringing-ai-powered-large-scale-code-change-to-enterprise-engineering-teams/) `UNVERIFIED` — I could not fetch https://sourcegraph.com/docs/batch-changes/agentic-batch-changes (returned an empty shell). Fetching that page, or the 7.5.0 changelog, would verify the delegation-to-Claude-Code claim from a first-party source.

## 3. Strongest capabilities

- `FACT` Trigram index over the default branch of *every* repo, with an explicit non-indexed fallback path, is a documented, honest scaling design rather than a benchmark claim (https://sourcegraph.com/docs/admin/architecture).
- `FACT` Batch Changes is a real reconciliation loop against code-host state, not a "generate a patch" toy: it tracks checks and review status per changeset until merge, across six code-host families including Gerrit and Perforce (https://sourcegraph.com/docs/batch-changes).
- `FACT` Deep Search keeps retrieval inside the customer's instance and sends only LLM calls out — the strongest posture in this file set for regulated buyers (https://sourcegraph.com/docs/deep-search).
- `FACT` Five GCP regions for single-tenant Cloud, plus true self-hosted (https://sourcegraph.com/docs/cloud; https://sourcegraph.com/docs/admin/deploy).
- `FACT` Deployment maturity: founded 2013, $223M raised through a $125M Series D at a $2.625B valuation in July 2021 (https://en.wikipedia.org/wiki/Sourcegraph).

## 4. Critical weaknesses

- `FACT` **The company split in half.** On 2025-12-02 Sourcegraph and Amp became two independent companies: Dan Adler became CEO of Sourcegraph; Quinn Slack and Beyang Liu — the founders — left to found Amp Inc. and remain only as board members (https://sourcegraph.com/blog/why-sourcegraph-and-amp-are-becoming-independent-companies; https://ampcode.com/news/amp-frontier-corporation). `INFERENCE` Both founders leaving for the AI product while the search business gets a new CEO is a strong signal about where the team believed the growth was.
- `FACT` **Cody has been demoted.** Cody Free, Cody Pro, and Cody in Enterprise Starter were all discontinued as of 2025-07-23 (new signups stopped 2025-06-25); only Cody Enterprise survives (https://sourcegraph.com/blog/changes-to-cody-free-pro-and-enterprise-starter-plans). As of 2026-08-04, **Cody is not mentioned anywhere on sourcegraph.com's homepage** (fetched 2026-08-04) — the product tiles are Deep Search, Code Search, Agentic Batch Changes, Code Insights, MCP, APIs, CLI. It still has a docs section, so it is not formally EOL, but it is no longer a marketed product.
- `FACT` **Not open source, and the door is shut.** Code Search was relicensed from Apache-2.0 to the proprietary Sourcegraph Enterprise license on 2023-06-13, and the monorepo was made private on 2024-08-22. `sourcegraph/sourcegraph-public-snapshot` is a frozen pre-migration copy, archived, last push 2024-09-02 (GitHub API, 2026-08-04). Nothing post-2024 can be read or borrowed.
- `INFERENCE` **Retrieval is lexical.** zoekt is trigram-based; Deep Search's tools are "modes of Code Search and Code Navigation." There is no documented code-property graph, no documented embedding index, and no documented cross-service edge model (HTTP calls between services, message queues, DI wiring). Basis: the architecture doc names only zoekt/searcher/gitserver, and the Deep Search doc names only Code Search/Navigation as agent tools.
- `FACT` **No public per-seat price.** The pricing page shows exactly one tier: "Enterprise — Starting at $16K," "Includes credits for AI features; scales with team size," everything else "Contact sales" (https://sourcegraph.com/pricing, fetched 2026-08-04). `INFERENCE` A $16K floor plus credit-based AI billing means no self-serve motion at all; the sales cycle is the product's biggest cost to the buyer.
- `FACT` **The AI story now depends on competitors' agents.** Agentic Batch Changes delegates judgment-heavy per-repo work to Claude Code or Codex (see §2). `INFERENCE` Sourcegraph is repositioning as context infrastructure *under* other vendors' agents rather than as the agent — which is exactly the layer Specera would also want to own, but also means Sourcegraph will not build the requirements/test/release legs itself.
- `UNVERIFIED` Compliance certifications. https://security.sourcegraph.com/ returned HTTP 403 to WebFetch on 2026-08-04, and https://sourcegraph.com/security does not list any certification by name. To verify: request access to the security portal or the Cody Security and Legal Whitepaper (https://sourcegraph.com/whitepapers/cody-security-and-legal). **Do not assume SOC 2 / ISO 27001 — I did not confirm either.**

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | No | No requirements feature in docs nav (Code Search, Cody, Deep Search, Sourcegraph 101, Tour) — https://sourcegraph.com/docs |
| Jira / work tracking | No | No issue-tracker integration documented or listed on the product nav — https://sourcegraph.com/ |
| Architecture / ADR | No | Code Insights produces "high-level code metrics and analytics" only — https://sourcegraph.com/ |
| Implementation | Partial | Cody Enterprise (autocomplete/chat) still documented but unmarketed; Agentic Batch Changes delegates edits to Claude Code/Codex — https://sourcegraph.com/docs/cody/faq |
| PR review | No | Batch Changes *creates and tracks* changesets; nothing in the docs reviews someone else's PR — https://sourcegraph.com/docs/batch-changes |
| Test generation | No | Not present in docs nav or product tiles |
| Security / pentest | Partial | CVE remediation is a named Agentic Batch Changes use case (remediation, not detection) — Agentic Batch Changes press release |
| Release | No | No release/versioning/changelog feature documented |
| Monitoring / incidents | Partial | "Code Monitoring" alerts on *code changes matching a search*, not on production incidents — https://sourcegraph.com/pricing ("Batch Changes, Insights, and Monitoring") |
| Maintenance / knowledge | Yes | Deep Search answers natural-language codebase questions with a source list; Code Search + Code Navigation — https://sourcegraph.com/docs/deep-search |

`INFERENCE` Sourcegraph covers roughly two of eleven Specera stages well (maintenance/knowledge, and the mechanical half of large-scale implementation). It is a **component-shaped competitor**, not a platform-shaped one.

## 6. Security, deployment, and license

**Deployment** `FACT`: two options. (a) Sourcegraph Cloud — single-tenant, "All infrastructure is hosted on Google Cloud Platform," customer instances "provisioned in fully segregated GCP environments," data encrypted in transit and at rest, backed up daily (https://sourcegraph.com/security; https://sourcegraph.com/docs/cloud). (b) Self-hosted — "Sourcegraph self-hosted instances do not send any customer code to other servers. Sourcegraph employees have no access to customer code" (https://sourcegraph.com/security). Note this last sentence is about the *search* product; Cody explicitly breaks it (below).

**Data residency** `FACT`: "Sourcegraph Cloud has 5 supported regions on GCP to meet data sovereignty requirements" (https://sourcegraph.com/docs/cloud). `UNVERIFIED` which five regions — the doc directs you to your account team.

**Training on customer code** `FACT`: "For Enterprise customers, Sourcegraph will not train on your company's data. Our third-party Language Model (LLM) providers do not train on your specific codebase" (https://sourcegraph.com/docs/cody/faq).

**Egress, concretely** `FACT`: "Cody operates by sending code snippets (up to 28 KB per request) to a third-party cloud service" (https://sourcegraph.com/docs/cody/faq). Providers named: Anthropic's Claude API (OpenAI configurable); autocomplete uses "the open source DeepSeek-Coder-V2 model, which is hosted by Fireworks.ai in a secure single-tenant environment located in the USA," and "No customer chat or autocomplete data — such as chat messages, or context such as code snippets or configuration — is stored by Fireworks.ai." Retention terms for Anthropic and OpenAI are deferred to https://sourcegraph.com/terms/cody-notice. `INFERENCE` So: self-hosted search is airtight, self-hosted *Cody* is not — code still leaves the network in 28 KB slices unless BYOK is used, and BYOK disables Deep Search.

**Prompt-injection surface** `INFERENCE`: Deep Search and Agentic Batch Changes both run agentic loops over untrusted repository content, and Agentic Batch Changes can delegate to Claude Code/Codex with write access to produce changesets. The documented mitigation is human review — "Engineers review and approve every changeset before merge." Basis: Deep Search doc (agentic loop over code search tools) + Agentic Batch Changes press release. No prompt-injection-specific control is documented.

**Pricing model** `FACT`: single Enterprise tier, "Starting at $16K," AI features billed via credits with "Org-wide credit pooling," "No monthly credit expiry," "Rollover on renewal"; 24×5 support; CSM and premium support are paid add-ons; volume pricing on request (https://sourcegraph.com/pricing, fetched 2026-08-04). No per-seat list price is published.

**Compliance** `UNVERIFIED`: see §4. Portal at https://security.sourcegraph.com/ (403 to automated fetch on 2026-08-04).

**License** `FACT`: Sourcegraph core is proprietary — Apache-2.0 until 2023-06-13, then the Sourcegraph Enterprise license, then private from 2024-08-22 (https://en.wikipedia.org/wiki/Sourcegraph; https://devclass.com/2024/08/21/sourcegraph-makes-core-repository-private-co-founder-complains-open-source-means-extra-work-and-risk/). `sourcegraph/sourcegraph-public-snapshot` is archived with an unrecognised ("NOASSERTION") license — **do not reuse it**. The one clean artifact is `sourcegraph/zoekt`, Apache-2.0 (GitHub API, 2026-08-04) — permissive, safe to vendor, notice file required.

## 7. Ideas to adopt or avoid

### Adopt
- **The changeset-spec / reconciliation split.** Separate "desired diff + PR body" (changeset spec) from "actual state on the code host," and run a controller that reconciles them continuously. Specera should model every PR it opens as a declarative desired-state record and reconcile — that is what makes fleet-scale change auditable and resumable rather than fire-and-forget. Source: https://sourcegraph.com/docs/batch-changes.
- **Deterministic-vs-judgment routing.** Agentic Batch Changes decides per change whether to *write a script* or *call an LLM agent*. Specera should make this an explicit planner decision with a recorded rationale, because scripted changes are cheap, reviewable, and reproducible, and LLM changes are none of those. Source: Agentic Batch Changes press release.
- **Mandatory source list on every agent answer.** Deep Search returns "a detailed list of sources contributing to the answer," showing which searches and files were examined. Specera should make an unsourced agent answer structurally impossible — the answer object should not serialise without its evidence set. Source: https://sourcegraph.com/docs/deep-search.
- **"Processing stays in-instance; only LLM calls egress."** Specera should adopt this as an explicit, documented architectural invariant and be able to show a customer the exact egress list, because it is the single sentence that unblocks regulated buyers. Source: https://sourcegraph.com/docs/deep-search.
- **`sourcegraph/zoekt` itself** (Apache-2.0) as the lexical tier under a graph tier — Specera needs fast literal/regex fallback for the cases a graph cannot answer, and this is a battle-tested implementation. (Another agent covers the zoekt repo; do not duplicate that analysis here.)

### Avoid
- **Indexing only the default branch.** Sourcegraph's fallback is a live grep via `searcher`. For Specera, PR review and test generation happen *on branches*, so a default-branch-only index would miss the primary use case.
- **Trigram-only retrieval as the foundation.** It cannot answer "what breaks if I change this signature" without a symbol/graph layer on top.
- **A $16K floor with no self-serve tier.** It removes bottom-up adoption entirely; the split of the company suggests the individual-developer motion had to be spun out to survive.
- **Marketing "code graph" over a trigram index.** The MCP tile on sourcegraph.com says "Code graph knowledge for agents" while the architecture doc names only zoekt trigrams. Specera should not borrow that vocabulary gap.

## 8. Build, borrow, buy, integrate, or reject

**Reject as a whole; borrow `zoekt` only.** The platform is proprietary and private since 2024-08-22, so there is nothing to build on and a $16K+ enterprise contract to buy something that covers two of Specera's eleven SDLC stages. The one reusable asset is `sourcegraph/zoekt` (Apache-2.0, actively maintained, last push 2026-07-29) as Specera's lexical search tier beneath a graph tier. Treat Sourcegraph as the incumbent to beat on *enterprise trust* (5 GCP regions, self-host, no-training guarantee) and to beat on *SDLC breadth*, where it does not compete at all. `INFERENCE` The founder departure to Amp and Cody's disappearance from the homepage suggest the AI layer is the softest place to attack.

## 9. Evidence

All URLs fetched 2026-08-04.

Primary (vendor / first-party):
- https://sourcegraph.com/ — product tiles: Deep Search, Code Search, Agentic Batch Changes, Code Insights, MCP, APIs, CLI. Cody and Amp absent.
- https://sourcegraph.com/pricing — single "Enterprise, Starting at $16K" tier; credit pooling; self-hosted + single-tenant cloud.
- https://sourcegraph.com/docs — nav: Code Search, Cody, Deep Search, Sourcegraph 101, Sourcegraph Tour.
- https://sourcegraph.com/docs/admin/architecture — zoekt trigram index of default branch; searcher; gitserver; worker; frontend; Postgres; codeinsights-db.
- https://sourcegraph.com/docs/deep-search — agentic loop, tools = Code Search/Navigation modes, in-instance processing, 5-minute limit, Enterprise/Enterprise Starter only, no BYOK.
- https://sourcegraph.com/docs/batch-changes — YAML batch spec, changeset specs, batch-changes-controller reconciliation, code hosts, Enterprise-only.
- https://sourcegraph.com/docs/batch-changes/agentic-batch-changes — **fetch failed (empty shell)**; Agentic Batch Changes detail is therefore secondary-sourced.
- https://sourcegraph.com/docs/cody/faq — no training on enterprise data; 28 KB snippets to third-party cloud; Anthropic/OpenAI; DeepSeek-Coder-V2 on Fireworks.ai, USA, no storage.
- https://sourcegraph.com/docs/cloud — single-tenant GCP, 5 supported regions.
- https://sourcegraph.com/security — GCP hosting, segregated environments; self-hosted sends no code out; links to security portal.
- https://security.sourcegraph.com/ — **HTTP 403**; compliance certifications unverified.
- https://sourcegraph.com/blog/changes-to-cody-free-pro-and-enterprise-starter-plans — Cody Free/Pro/Enterprise Starter discontinued 2025-07-23; signups closed 2025-06-25; $10/$40 Amp credits; Cody Enterprise unaffected.
- https://sourcegraph.com/blog/why-sourcegraph-and-amp-are-becoming-independent-companies — 2025-12-02; Dan Adler CEO of Sourcegraph; Slack + Liu found Amp Inc.; investors Craft, Redpoint, Sequoia, Goldcrest, a16z on both boards.
- https://ampcode.com/news/amp-frontier-corporation — 2025-12-02; Amp "spun out of Sourcegraph to become an independent research lab"; "Amp is profitable"; no funding figures given.
- https://sourcegraph.com/terms/cody-notice — referenced for Anthropic/OpenAI retention terms (not fetched).
- https://sourcegraph.com/whitepapers/cody-security-and-legal — referenced, not fetched.

Secondary / press:
- https://en.wikipedia.org/wiki/Sourcegraph — founded 2013 by Quinn Slack and Beyang Liu; funding rounds Oct 2017 $20M A, Mar 2020 $23M B, Jul 2020 $5M B, Dec 2020 $50M C, Jul 2021 $125M D at $2.625B; $223M total; license timeline 2016 Fair Source → 2018 Apache-2.0 → 2023-06-13 proprietary → 2024-08-22 private.
- https://devclass.com/2024/08/21/sourcegraph-makes-core-repository-private-co-founder-complains-open-source-means-extra-work-and-risk/ — repo made private, Quinn Slack's stated reasons.
- https://cioinfluence.com/machine-learning/sourcegraph-launches-agentic-batch-changes-in-public-beta-bringing-ai-powered-large-scale-code-change-to-enterprise-engineering-teams/ — Agentic Batch Changes public beta (~2026-07-08), delegation to Claude Code / Codex. Syndicated press release, not independently corroborated.

Commands run (read-only, 2026-08-04):
- `curl https://api.github.com/repos/{sourcegraph/zoekt, sourcegraph/scip, sourcegraph/sourcegraph-public-snapshot, sourcegraph/cody, google/zoekt, sourcegraph/amp}` — `sourcegraph/zoekt`: Apache-2.0, 1,806 stars, pushed 2026-07-29, not archived. `google/zoekt`: archived, last push 2024-01-16. `sourcegraph/sourcegraph-public-snapshot`: archived, 10,300 stars, license NOASSERTION, last push 2024-09-02. `sourcegraph/cody` and `sourcegraph/amp`: **404 Not Found**. `sourcegraph/scip`: 301 redirect (repo moved/renamed — not resolved).

Note on excluded sources: searches surfaced many AI-generated review farms (toolchase.com, aiidelist.com, weavai.app, aiagentsquare.com, aipedia.wiki, symvanta.com) asserting a "$59/user/month Cody Enterprise" price. **That figure appears on no Sourcegraph page and is not used in this document.**
