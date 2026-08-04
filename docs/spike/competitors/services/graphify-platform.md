# Graphify Platform (Graphify Labs enterprise layer)

The paid, early-access tier that Graphify Labs (YC S26) is selling on top of the Apache-2.0 `graphify` CLI: PR review over the code knowledge graph, formal verification at the merge gate, an engineering digest, and a Jira connector — all self-hosted in the customer's own infrastructure.

## 1. Verdict

**This is the closest competitor to Specera's actual thesis in this entire file set**, and the only one where the overlap is deliberate rather than incidental: a knowledge graph over code *and* Jira, feeding PR review and a merge gate. The single thing it does better than anything else is **provenance-labelled retrieval** — every edge is tagged `EXTRACTED` / `INFERRED` / `AMBIGUOUS`, so an agent can distinguish AST ground truth from model guesswork, which no other product here does. What kills it, today: it is a **two-person company** (YC profile, 2026-08-04) with the entire enterprise layer in "early access" to design partners, **no public pricing, no security page, no compliance certifications published, and no independently verified customer**. `INFERENCE` Specera's window is the 12-24 months before Graphify Labs can staff an enterprise product — but the window is narrow, because the free tier is already at ~102K GitHub stars, which is distribution Specera will not match.

`FACT` The free CLI is analysed by another agent under `docs/spike/competitors/graphify.md` — this file covers only the commercial offering. Do not duplicate.

## 2. Core architecture and unique mechanism

`VENDOR CLAIM` (https://graphify.com/enterprise, fetched 2026-08-04) — the enterprise layer is "built on the same on-device graph, self-hosted in your VPC." So the architecture below is the free tier's architecture, which the paid tier inherits.

**Extraction.** `FACT` "Graphify parses code locally with tree-sitter: deterministic AST extraction, no model call, no telemetry, nothing uploaded" (https://graphify.com/faq). 36 languages via tree-sitter, plus non-code artifacts — "docs, PDFs, SQL, Postgres, Terraform" — which are connected **by model inference, not by parsing** (https://graphify.com/docs). `INFERENCE` This is the split that matters: code→code edges are deterministic; code→doc, code→schema, and code→ticket edges are LLM-inferred and therefore probabilistic.

**Provenance labelling — the unique mechanism.** `FACT` Every relation carries one of three tags: `EXTRACTED` (from the AST, code-grounded), `INFERRED` (connected by the configured model), `AMBIGUOUS` ("couldn't be fully resolved"). The stated purpose: "an agent always knows what is grounded in code and what is a guess" (https://graphify.com/llms-full.txt, https://graphify.com/docs). Accuracy framing: "EXTRACTED edges are deterministic: they come straight from the AST, so a call or import edge is as reliable as your parser" (https://graphify.com/faq).

**Storage / output format.** `FACT` Three artifacts in `graphify-out/`: `graph.json` (machine-readable), `graph.html` (interactive visualisation), `GRAPH_REPORT.md` ("architecture report (god nodes, surprising connections, the 'why')") (https://graphify.com/docs). `INFERENCE` This is a **file-based graph, not a database** — no Neo4j/Kuzu/DuckDB is named anywhere in the docs. That is why it can be committed to a repo and shared by a team, and also why it will not support concurrent multi-user query at enterprise scale without a different backend.

**Query path.** `FACT` An MCP server exposing **10 tools**: `query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `get_community`, `god_nodes`, `graph_stats`, `list_prs`, `get_pr_impact`, `triage_prs` (https://graphify.com/mcp, https://graphify.com/docs). Answers are "explicit graph paths with real file:line citations" (https://www.graphify.com). Explicitly positioned against vector retrieval — the README subtitle is "local deterministic AST parsing, every edge explained, **no vector store**" (GitHub API description, 2026-08-04), with a dedicated https://graphify.com/vs/rag page.

**PR surface (the seed of the commercial product).** `FACT` `graphify prs` maps open pull requests onto the graph, with `--triage` and `--conflicts` flags; the three PR-related MCP tools are `list_prs`, `get_pr_impact`, `triage_prs` (https://graphify.com/docs). `INFERENCE` The paid "graph-aware code review" is the productised version of these three tools plus a hosted runner.

**Incremental update.** `FACT` "`/graphify . --update` rescans only changed files, which is far cheaper than a full pass"; a `--mode deep` multi-pass mode also exists (https://graphify.com/faq, https://graphify.com/docs).

**Enterprise-only capabilities.** `VENDOR CLAIM` Four, all early access:
1. **Formal verification at the merge gate** — the strongest and least ordinary claim. Reported as: Graphify "proves an edit behaves identically, or hands you the exact input that breaks it — as a runnable test." `UNVERIFIED` — this wording comes from search-result summarisation, not a page I fetched verbatim, and the verifier (SMT solver? symbolic execution? property-based fuzzing?) is **never named in any public document**. To verify: obtain design-partner access, or a technical blog post naming the verification engine and the language subset it supports. Treat as unproven until then.
2. **Graph-aware code review.**
3. **Engineering digest** report.
4. **Jira connector** — `FACT` per the YC profile: "Graphify builds queryable knowledge graphs from local codebases, documentation, **and Jira**" (https://www.ycombinator.com/companies/graphify-labs).

## 3. Strongest capabilities

- `FACT` Provenance tagging of every edge (`EXTRACTED`/`INFERRED`/`AMBIGUOUS`) — https://graphify.com/faq. No other product in this file set publishes edge-level confidence.
- `FACT` Zero-egress by construction for the core: no account, no API key, no telemetry, on-device tree-sitter parsing — https://graphify.com/faq. The enterprise tier keeps this shape ("self-hosted in your VPC") rather than inverting it, which is the opposite of the Sourcegraph/Cody pattern.
- `FACT` Explicit anti-RAG architectural position with a dedicated comparison page — https://graphify.com/vs/rag; repo description says "no vector store" (GitHub API 2026-08-04).
- `FACT` PR-graph integration already shipped in the *free* tier: `list_prs`, `get_pr_impact`, `triage_prs` — https://graphify.com/docs.
- `FACT` Real incremental re-index (`--update`, changed files only) — https://graphify.com/faq. Most graph tools in this category rebuild.
- `FACT` Distribution: 101,867 stars / 9,896 forks, repo created 2026-04-03, last push 2026-08-01 (GitHub API, 2026-08-04); YC profile claims "100K+ GitHub stars, ~4.2M downloads." That is roughly four months from creation to 100K stars.
- `VENDOR CLAIM` Named production users on the YC profile: Rootly, Geotab, Tweddle Group, Superagent (https://www.ycombinator.com/companies/graphify-labs). `UNVERIFIED` — no case study, no customer quote, no logo wall found; verify by finding a first-party statement from any of the four.

## 4. Critical weaknesses

- `FACT` **Two employees.** YC profile lists team size 2, one founder (Safi Shamsi, CEO), London, UK (https://www.ycombinator.com/companies/graphify-labs). `INFERENCE` Formal verification, a Jira connector, graph-aware review, a digest product, VPC deployment, *and* enterprise support cannot all be delivered by two people. Expect most of the enterprise surface to be roadmap for some time.
- `FACT` **No public pricing.** https://graphify.com/pricing lists exactly two rows: the free open-source core, and "Enterprise (early access)" with no price. **No public pricing found** — do not estimate.
- `FACT` **No security or trust page exists.** The site index at https://graphify.com/llms.txt enumerates every page: home, docs, what-is-graphify, install, tutorial, mcp, docs/mcp, faq, vs/rag, integrations, changelog, pricing, llms-full.txt, GitHub, PyPI, Discord. There is **no security page, no trust centre, no subprocessor list, no DPA, no compliance page**. `INFERENCE` No SOC 2, no ISO 27001, no FedRAMP — a regulated enterprise cannot complete a vendor review against this. This is the single largest opening for Specera.
- `UNVERIFIED` **The formal-verification claim is unsubstantiated.** No engine named, no language scope, no soundness/completeness statement, no benchmark. Verify via a design-partner technical doc.
- `INFERENCE` **File-based graph will not survive multi-repo enterprise scale.** Basis: outputs are three files (`graph.json`/`graph.html`/`GRAPH_REPORT.md`), no database named in any doc. Cross-repository edges are not mentioned anywhere on the site — the unit of work is "any folder." A service-to-service call graph across repos appears out of scope.
- `INFERENCE` **Non-code edges are LLM-guessed.** Code→PDF, code→SQL-schema, code→Terraform, and (by extension) code→Jira edges are `INFERRED`, per the docs' own split. So the exact links Specera cares most about — requirement ↔ code — are the least reliable ones in Graphify's graph, by Graphify's own labelling.
- `FACT` **No published benchmark of any kind.** No accuracy evaluation appears in llms-full.txt or the FAQ; the accuracy answer is an argument-from-construction ("as reliable as your parser"), not a measurement.
- `INFERENCE` **Company focus may be drifting off code.** `UNVERIFIED` Multiple secondary sources describe a second product, **Penpax**, as "the enterprise layer on top of graphify" applied to "meetings, browser history, files, emails" for "lawyers, consultants, executives, doctors, researchers." Penpax is **not mentioned on graphify.com or the YC profile**, and the sources (ai.miraheze.org wiki, SEO blogs) are weak. To verify: find a first-party Penpax announcement. If real, it means the founder's enterprise attention is pointed at knowledge work generally, not the SDLC.
- `FACT` **Namespace confusion / typosquat risk.** The PyPI package is `graphifyy` (double-y), the canonical repo moved from `safishamsi/graphify` (now 301-redirecting) to `Graphify-Labs/graphify`, and search surfaces at least four unrelated look-alike domains (graphify.net, graphify.homes, graphify.com is the real one) plus mirror repos (`sharkkyyy10/graphify-`, `collabsoft/ai_graphify`, `vchain/graphifyy`). `INFERENCE` A buyer cannot easily tell which artifact is authentic — a supply-chain concern for anyone installing it.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements / PRD | Partial | Ingests "docs, PDFs" into the graph, but only via `INFERRED` model edges, not parsing — https://graphify.com/docs |
| Jira / work tracking | Partial | "builds queryable knowledge graphs from local codebases, documentation, and Jira" — https://www.ycombinator.com/companies/graphify-labs. Enterprise, early access. No Jira docs page exists. |
| Architecture / ADR | Partial | `GRAPH_REPORT.md` = "architecture report (god nodes, surprising connections, the 'why')"; `get_community`, `god_nodes` MCP tools — https://graphify.com/docs. Descriptive only; no ADR authoring or decision record. |
| Implementation | No | It is a retrieval skill for other agents (Claude Code, Cursor, Codex, Gemini CLI); it writes no code — https://www.graphify.com |
| PR review | Yes (enterprise) | Free tier: `graphify prs --triage --conflicts`, `list_prs`/`get_pr_impact`/`triage_prs`. Paid: "graph-aware code review" — https://graphify.com/docs, https://graphify.com/enterprise |
| Test generation | Partial | `VENDOR CLAIM`/`UNVERIFIED` only: verification reportedly returns "the exact input that breaks it — as a runnable test." No test-generation feature documented. |
| Security / pentest | No | Nothing on the site; no SAST, no dependency scanning, no CVE surface |
| Release | No | Not present in any documented page |
| Monitoring / incidents | No | Not present in any documented page |
| Maintenance / knowledge | Yes | This is the core product: graph query with file:line citations, incremental `--update`, god-node/community analysis — https://graphify.com/docs |

`INFERENCE` Graphify Platform reaches **four** of Specera's eleven stages to some degree (requirements-ish, Jira, PR review, maintenance) — more than Sourcegraph, and the two it reaches that matter most (Jira + PR review) are precisely Specera's spine. But three of the four are early-access and undocumented.

## 6. Security, deployment, and license

**Pricing model** `FACT`: two tiers on https://graphify.com/pricing — core tool "free, open source (Apache 2.0), no account, no limits"; "Enterprise (early access)" with features "merge-gate verification, graph-aware review, engineering digest, self-hosted" and **no price shown**. **No public pricing found.** No seat model, no usage model, no minimum published.

**Deployment** `VENDOR CLAIM`: enterprise is "built on the same on-device graph, self-hosted in your VPC" (https://graphify.com/enterprise). `INFERENCE` There is **no SaaS option** — which is unusual and, for Specera's target buyer, actually an advantage Graphify holds.

**Data residency** `INFERENCE`: moot for the core tool — nothing leaves the machine, so residency is wherever the developer's laptop or the customer's VPC is. `FACT` basis: "no account, no API keys, nothing leaves the machine" (https://graphify.com/llms-full.txt). Caveat: `INFERRED` edges are produced by "the configured model," i.e. the user's own LLM credentials — so egress exists the moment non-code artifacts are linked, and it goes wherever that model is hosted. Graphify does not broker it.

**Training on customer code** `INFERENCE`: Graphify Labs cannot train on customer code for the core tool because it never receives it (no telemetry, no account). `UNVERIFIED` There is **no written policy statement** to this effect anywhere on the site — no DPA, no terms page in the site index. For a procurement process, absence of a policy is not the same as a policy. To verify: request a DPA from founders.

**Compliance** `FACT`: **no compliance certification is claimed anywhere.** The full site index (https://graphify.com/llms.txt) contains no security, trust, compliance, DPA, or subprocessor page. `INFERENCE` No SOC 2 Type II, no ISO 27001, no FedRAMP. For a 2-person YC S26 company founded April 2026 this is expected, and it is a hard blocker for regulated buyers.

**Auth / secrets / egress surface** `INFERENCE`: the core tool has no auth model because it has no server. The MCP server runs over stdio or HTTP (https://graphify.com/mcp). Secrets handling is the user's LLM API key for `INFERRED` edges. `UNVERIFIED` The enterprise layer must have an auth model (Jira OAuth, code-host tokens, merge-gate CI credentials) but **none of it is documented publicly**.

**Prompt-injection surface** `INFERENCE`: material and under-addressed. The graph deliberately ingests untrusted, attacker-influenceable artifacts — PDFs, Markdown docs, PR titles/bodies (`list_prs`), and Jira tickets — and serves them to a coding agent via MCP. A malicious PR description or ticket becomes graph content that an agent reads as context. The `INFERRED`/`AMBIGUOUS` labels give a *partial* mitigation (an agent can be told to distrust non-`EXTRACTED` content) but no injection-specific control is documented. Basis: MCP tool list + document ingestion claims, both from https://graphify.com/docs.

**License** `FACT`: **Apache-2.0**, verified from the repository, not from memory — `GET https://api.github.com/repos/Graphify-Labs/graphify/license` returns `path: LICENSE`, `spdx_id: Apache-2.0`, body beginning "Apache License / Version 2.0, January 2004" (2026-08-04). Default branch is `v8`. Note: `raw.githubusercontent.com/Graphify-Labs/graphify/main/LICENSE` 404s because the default branch is not `main`. `INFERENCE` Apache-2.0 means Specera may vendor, fork, or embed the core graph builder commercially, subject only to notice/attribution and the patent-termination clause. The enterprise layer is proprietary and unavailable.
`FACT` Secondary sources claiming Graphify is MIT-licensed (ai.miraheze.org) are **wrong** — the repo LICENSE is Apache-2.0.

## 7. Ideas to adopt or avoid

### Adopt
- **Edge-level provenance tags.** Specera should stamp every graph edge `EXTRACTED` (parser-derived), `INFERRED` (model-derived), or `AMBIGUOUS` (unresolved), and expose the tag through the retrieval API so downstream agents can weight or refuse guessed edges. This is the single most transferable idea in this file, it costs almost nothing to implement, and it directly attacks the "AI made something up" objection. Source: https://graphify.com/faq.
- **Make the requirement↔code edge type explicit and honest.** Graphify's own architecture proves the hard part: code→code is deterministic, code→doc/ticket is a guess. Specera's differentiator should be *raising the quality of that specific edge* (e.g. via commit-message/branch-name/PR-link triangulation to Jira keys, which is deterministic evidence) rather than accepting an LLM guess. Source: the EXTRACTED/INFERRED split, https://graphify.com/docs.
- **`get_pr_impact` / `triage_prs` as first-class retrieval primitives.** Specera should expose "what does this PR touch, transitively, in the graph" as a named tool rather than making the agent assemble it from neighbours. Source: https://graphify.com/mcp.
- **`god_nodes` and `get_community` as maintenance signals.** Community detection plus high-degree-node detection turns the graph into an architecture-health report (`GRAPH_REPORT.md`) rather than only a lookup index — cheap, and it produces an artifact a manager will actually read. Source: https://graphify.com/docs.
- **Ship a genuinely zero-egress mode.** Graphify's "no account, no API keys, nothing leaves the machine" is a procurement cheat code. Specera should be able to run its deterministic layers (parse, graph build, impact analysis, diff triage) with the network off, and be explicit about exactly which features require egress. Source: https://graphify.com/faq.
- **Incremental `--update` semantics as the default.** Rescan changed files only; make full rebuild the exception. Source: https://graphify.com/faq.

### Avoid
- **Three-files-on-disk as the graph store.** Fine for one repo on one laptop; it will not serve multi-repo, multi-user, cross-service queries, and it has no answer for concurrent writes or index freshness across a fleet.
- **Selling "formal verification" without naming the engine.** Graphify claims it and documents nothing. Specera should either name the technique and its language/soundness limits or not use the word.
- **Shipping an enterprise tier with no security page.** Whatever Specera builds, the trust surface (DPA, subprocessors, retention, residency, training policy) must exist on day one — it is the cheapest possible differentiator against this competitor.
- **Model-inferring the requirements→code link.** See Adopt above; inheriting this shortcut inherits Graphify's weakest edges.

## 8. Build, borrow, buy, integrate, or reject

**Borrow (the mechanism), reject (the vendor).** Apache-2.0 on the core means Specera can legally read, fork, or vendor the graph builder — verified from the repo LICENSE, `spdx_id: Apache-2.0`. But the commercial layer is early-access vapour from a two-person company with no pricing, no security page, and no compliance posture, so there is nothing to buy and no partner to integrate with at enterprise scale. `INFERENCE` The right posture is: take the provenance-tagging idea and the PR-impact primitives, then compete directly on the two things Graphify cannot ship soon — a real enterprise trust surface, and a deterministic requirement↔code link. Track it closely: at ~102K stars and YC-funded, distribution is its weapon and it can hire.

## 9. Evidence

All URLs fetched 2026-08-04.

Primary (vendor / first-party):
- https://www.graphify.com — "Graphify turns your codebase into a knowledge graph your AI assistant queries instead of grepping"; "Answers are explicit graph paths with real file:line citations"; "Runs on-device: no account, no API keys, no telemetry"; install via `uv tool install graphifyy`.
- https://graphify.com/pricing — free Apache-2.0 core; "Enterprise (early access)" = "merge-gate verification, graph-aware review, engineering digest, self-hosted"; **no price disclosed**.
- https://graphify.com/enterprise — "verification at the merge gate, graph-aware code review, and an engineering digest"; "built on the same on-device graph, self-hosted in your VPC"; "Early access". No pricing, no contact, no compliance, no company name on the page.
- https://graphify.com/docs — 36 languages via tree-sitter; docs/PDFs/SQL/Postgres/Terraform via model inference; outputs `graph.html`, `GRAPH_REPORT.md`, `graph.json` in `graphify-out/`; 10 MCP tools (`query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `get_community`, `god_nodes`, `graph_stats`, `list_prs`, `get_pr_impact`, `triage_prs`); `graphify prs --triage --conflicts`; provenance tags EXTRACTED/INFERRED/AMBIGUOUS; `--update` incremental, `--mode deep`.
- https://graphify.com/faq — local tree-sitter, no telemetry, nothing uploaded; Apache-2.0, no API keys; no hard size limit; `--update` rescans only changed files, "far cheaper than a full pass"; "EXTRACTED edges are deterministic"; enterprise = merge-gate verification + graph-aware review + digest, in your own infrastructure.
- https://graphify.com/llms.txt — complete site index (see §4): **no security, trust, compliance, DPA, terms, or subprocessor page exists**.
- https://graphify.com/llms-full.txt — "no account, no API keys, nothing leaves the machine"; PyPI package is `graphifyy` (double-y); MCP server with 10 graph tools; enterprise early access incl. self-hosted VPC; no benchmarks present.
- https://graphify.com/mcp — 10 tools, stdio and HTTP transports.
- https://graphify.com/vs/rag — explicit anti-vector-retrieval positioning.
- https://graphify.com/what-is-graphify — **HTTP 404 on fetch** (listed in llms.txt but not resolvable 2026-08-04).
- https://www.ycombinator.com/companies/graphify-labs — Graphify Labs, batch Summer 2026, "On-device knowledge graph engine for enterprises"; "builds queryable knowledge graphs from local codebases, documentation, and Jira"; "100K+ GitHub stars, ~4.2M downloads"; users listed as Rootly, Geotab, Tweddle Group, Superagent; "The enterprise layer reviews pull requests and formally verifies code changes"; founder Safi Shamsi (CEO); **team size 2**; London, UK; tags Developer Tools / Reinforcement Learning / Open Source.

Commands run (read-only, 2026-08-04):
- `curl https://api.github.com/repos/Graphify-Labs/graphify` → 101,867 stars, 9,896 forks, created 2026-04-03, pushed 2026-08-01, license Apache-2.0, homepage https://www.graphify.com, default branch `v8`, not archived. Description ends: "local deterministic AST parsing, every edge explained, **no vector store**."
- `curl https://api.github.com/repos/Graphify-Labs/graphify/license` → `path: LICENSE`, `spdx_id: Apache-2.0`, body confirmed as Apache License 2.0. **License verified from the repo, not from memory.**
- `curl https://api.github.com/repos/safishamsi/graphify` → 301 Moved Permanently (repo relocated to the Graphify-Labs org).
- `curl https://raw.githubusercontent.com/Graphify-Labs/graphify/main/LICENSE` → 404 (default branch is `v8`, not `main`).

Weak / secondary sources — used only where explicitly labelled `UNVERIFIED`, and named here so they can be discounted:
- https://ai.miraheze.org/wiki/Graphify — source of the "MIT license" claim (**contradicted by the repo LICENSE**), the "21 Fortune 500 in pipeline" figure, and the Penpax description. Unreliable.
- Search-result summaries describing formal verification as "proves an edit behaves identically, or hands you the exact input that breaks it — as a runnable test" and the Jira connector "rolling out to design partners" — no first-party page fetched carrying this wording.
- SEO/AI-content farms surfaced but **not used**: graphify.net, graphify.homes, alphamatch.ai, aurigait.com, openapps.pro, saurabhsharma.dev. Several report a stale "63.2K stars" figure; the GitHub API says 101,867.
