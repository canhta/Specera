# DeepWiki / Devin (Cognition)

Cognition ships three coupled things: **Devin**, a cloud autonomous coding agent billed in ACUs; **Devin Review**, a hosted PR-review surface for GitHub/GitLab; and **DeepWiki**, an auto-generated, chat-queryable architecture wiki over a repository (free tier at deepwiki.com for public GitHub repos).

*All web evidence fetched 2026-08-04.*

## 1. Verdict

A **component competitor with one genuinely differentiated asset** — DeepWiki is the best public demonstration that an auto-generated, source-linked architecture wiki is achievable and useful, and it is the single capability in this competitive set that maps onto Specera's "architecture/knowledge" node. Everything else is agent-shaped: Devin executes tasks, Devin Review annotates diffs, neither of which touches requirements, release, or monitoring. What kills it as a platform rival is that Cognition owns no system of record — it plugs into GitHub/GitLab rather than owning them — and, decisively for enterprise, `FACT` Cognition **trains on customer data by default** on free and paid plans, with opt-out only via Data Controls and express written consent required only for Enterprise (https://docs.devin.ai/admin/security). `INFERENCE`: for a regulated-SDLC product, that default is disqualifying as a dependency and exploitable as a differentiator.

Relationship note: `FACT` the open-source `AsyncFuncAI/deepwiki-open` is an independent third-party reimplementation, not a Cognition product — its README describes it as "my own implementation attempt of DeepWiki" (https://github.com/AsyncFuncAI/deepwiki-open). That repo is analysed by another agent; nothing here rests on its code.

## 2. Core architecture and unique mechanism

**DeepWiki** — `FACT` "DeepWiki automatically indexes repositories and creates documentation during onboarding", analysing codebase structure to produce "architecture diagrams, documentation, and links to source code" (https://docs.devin.ai/work-with-devin/deepwiki). The distinguishing mechanism is that generation is **steerable by a repo-committed config**: `.devin/wiki.json` supplies repo notes and specifies the exact pages to create; regeneration occurs after that file is modified and committed (same URL). `FACT` The wiki backs Ask Devin's code search to give "detailed and accurate answers grounded in your code". `FACT` A DeepWiki MCP server exposes "basic documentation and Q&A capabilities" to external agents.

`FACT` Public tier: deepwiki.com indexes popular open-source projects and accepts user-submitted **public** GitHub repos, positioned as "up-to-date documentation you can talk to, for every repo in the world" / "Deep Research for GitHub" (https://deepwiki.com/). Private repos require the Devin app.

`UNVERIFIED` The actual indexing pipeline — parsers, embedding model, chunking, graph vs vector store — is entirely undisclosed in public docs. Nothing in the fetched pages names a parser, grammar, or index format. Would be verified by a Cognition engineering post or by network/behaviour analysis of the app; treat any architectural claim about DeepWiki as unsupported.

`UNVERIFIED` **Refresh / staleness handling.** The docs describe regeneration on `.devin/wiki.json` change but "don't explicitly detail automatic refresh schedules" (https://docs.devin.ai/work-with-devin/deepwiki). There is no documented mechanism by which the wiki knows it is stale relative to `HEAD`. This is precisely the freshness question the spike cares about, and the answer is: not publicly addressed.

**Devin Review** — `FACT` Reviews trigger automatically (when enabled) on PR open, new commits, or draft→ready transition. Context comes from repo instruction files — `REVIEW.md`, `AGENTS.md`, `CONTRIBUTING.md`, `.cursorrules`, plus admin-configurable file globs — and from codebase-aware chat that pulls context beyond the diff (https://docs.devin.ai/work-with-devin/devin-review). Analysis produces: logical (not alphabetical) diff grouping, code-movement detection, bug findings with severe/non-severe confidence, and security findings **with CWE classification** in a dedicated Security section alongside Bugs and Flags.

`FACT` Platform support is asymmetric: GitHub (incl. Enterprise Server and Enterprise Cloud) full support; GitLab (incl. self-managed) full support **except** partial merge/auto-merge; **Bitbucket and Azure DevOps not supported** (same URL).

`FACT` Notably, the Devin Review docs make **no mention of DeepWiki or wiki-based indexing** as review context — the two products do not visibly share an index at the documentation level.

**Devin** — `FACT` Web app at app.devin.ai with an embedded shell, IDE, and browser; a CLI for local "quick fixes, code exploration, and interactive coding" that can hand off to cloud Devin; Slack and Microsoft Teams integrations for tagging Devin in discussions (https://docs.devin.ai/).

**Billing unit** — `VENDOR CLAIM` (secondary sources, official pricing page returned 404 on both cognition.ai/pricing and cognition.com/pricing on 2026-08-04): an ACU is "a normalized measure of the computing resources Devin uses… such as virtual machine time, model inference, and networking bandwidth", roughly 15 minutes of active Devin work. `FACT` from official docs: Devin Review consumes ACUs from a shared org pool, sized XS (≤2.25 ACUs) to XL (>18 ACUs), and "Per-org ACU limits configured in Settings > Organizations apply to Devin sessions only — Review consumption is tracked at the enterprise level" (https://docs.devin.ai/work-with-devin/devin-review).

## 3. Strongest capabilities

- `FACT` **Config-steered wiki generation.** `.devin/wiki.json` lets a team dictate page structure and supply repo notes, and commits trigger regeneration — documentation-as-code for generated documentation (https://docs.devin.ai/work-with-devin/deepwiki).
- `FACT` **Architecture diagrams with source links.** DeepWiki emits diagrams *and* "links to source code", i.e. the generated artifact is navigable back to the file that justified it (same URL). This is the closest thing in the whole competitive set to a durable architecture→code edge.
- `FACT` **Free public proof at scale.** deepwiki.com hosts wikis for hundreds of major OSS projects (VSCode, TensorFlow, React) — an unusually strong public demonstration that the approach generalises across languages and repo sizes.
- `FACT` **MCP exposure of the wiki.** DeepWiki MCP makes the generated knowledge consumable by third-party agents — a distribution channel, and a possible input for Specera.
- `FACT` **CWE-classified security findings inside PR review**, plus security findings surfaced into the review chat (Ask Devin), rather than as a separate scanner report (https://docs.devin.ai/work-with-devin/devin-review, https://docs.devin.ai/release-notes/2026).
- `FACT` **Single-tenant VPC option.** Customer Dedicated deployment runs the Devbox in a "customer-isolated single-tenant VPC" reached over AWS PrivateLink or IPSec, with the Brain remaining in Cognition Cloud (https://docs.devin.ai/enterprise/deployment/overview).

## 4. Critical weaknesses

- `FACT` **Trains on customer data by default.** "Cognition uses customer data for model training by default on free/paid plans"; paid users may opt out via Data Controls; only Enterprise requires "express prior written consent" (https://docs.devin.ai/admin/security). `INFERENCE`: any team below Enterprise that has not actively opted out has shipped proprietary code into a training pipeline. This is the hardest single finding against Devin and the sharpest contrast with GitHub (`does not use Business/Enterprise data to train`) and GitLab (`does not train generative AI models`).
- `FACT` **Cannot gate a merge.** "Devin Review does not block merges… only humans can execute merge operations" (https://docs.devin.ai/work-with-devin/devin-review). It displays mergeability and required checks but contributes no enforceable control.
- `UNVERIFIED` **No documented staleness signal for DeepWiki.** Regeneration is documented only as a consequence of editing `.devin/wiki.json`; nothing states how a wiki generated at commit A is invalidated by commit B. Would be verified by observing a wiki's regeneration behaviour after unrelated commits, or by a vendor statement.
- `FACT` **DeepWiki and Devin Review are not documented as sharing an index.** The review docs list instruction files and codebase chat as context and never reference the wiki. `INFERENCE`: the architecture knowledge Cognition generates is not demonstrably feeding the place where architectural drift would be caught.
- `FACT` **No Bitbucket, no Azure DevOps** for review (same URL) — narrower than CodeRabbit's four platforms.
- `FACT` **Opaque billing at the review layer.** Review ACU consumption is tracked at enterprise level and explicitly escapes the per-org ACU limits admins configure. `INFERENCE`: review spend is not controllable with the same lever as session spend.
- `UNVERIFIED` **Pricing is not verifiable from source.** Both https://cognition.ai/pricing and https://cognition.com/pricing returned HTTP 404 on 2026-08-04. Secondary sources report Core ~$20/mo, Team $500/mo with 250 ACUs at $2.00/ACU, Enterprise custom (~$2.25/ACU); treat all of these as unconfirmed. Would be verified by the live pricing page or an order form.
- `UNVERIFIED` **No data residency statement, no ISO certification, no subprocessor list** in the security doc — it names only SOC 2 Type II (March 2024) and defers to https://trust.cognition.ai/ (https://docs.devin.ai/admin/security).
- `UNVERIFIED` DeepWiki page limits reported as 30 (standard) vs 80 (enterprise) in the docs summary but not stated as authoritative. Verify against the DeepWiki settings UI.

## 5. SDLC coverage

| Stage | Covered | Evidence |
|---|---|---|
| Requirements/PRD | No | No requirement, PRD, or acceptance-criteria artifact in any fetched doc. Devin Review reads `REVIEW.md`/`AGENTS.md`/`CONTRIBUTING.md`, not requirements. |
| Jira/work tracking | No | Docs list Slack and Microsoft Teams integrations only (docs.devin.ai/). `UNVERIFIED`: no Jira/Linear integration documented; would be verified via the integrations index. |
| Architecture/ADR | **Partial — strongest row** | DeepWiki generates architecture diagrams + source links, steered by `.devin/wiki.json` (docs.devin.ai/work-with-devin/deepwiki). It documents *as-built* architecture; it records no decision, no rationale, no ADR lifecycle. |
| Implementation | **Yes** | Devin sessions write, run, and test code in an embedded shell/IDE/browser; CLI for local work with cloud handoff (docs.devin.ai/). |
| PR review | **Yes** | Devin Review: auto-trigger, logical diff grouping, code-movement detection, severity-scored bugs, CWE-tagged security findings (docs.devin.ai/work-with-devin/devin-review). |
| Test generation | Partial | Devin "can write, run and test code" within a session (docs.devin.ai/). No dedicated test-generation or Gherkin/BDD surface documented. |
| Security/pentest | Partial | Security section in review with CWE classification. No DAST, no pentest, no vulnerability lifecycle or SLA tracking. |
| Release | No | Auto-merge toggle on the Devin Review merge button (docs.devin.ai/release-notes/2026) is the entire release story — no versioning, changelog, or deployment. |
| Monitoring/incidents | No | Nothing in any fetched doc. |
| Maintenance/knowledge | **Partial** | DeepWiki + Ask Devin code search grounded in the wiki; DeepWiki MCP for external agents. Freshness unaddressed (see §4). |

`INFERENCE` (rests on the table): Cognition covers the *middle* of the lifecycle — implement, review, understand — and none of the ends. It is not competing for the lifecycle; it is competing for the developer's hands. For Specera it is a component-shaped rival on exactly one row (architecture/knowledge) plus a strong incumbent on two rows Specera was probably not going to win anyway.

## 6. Security, deployment, and license

**License** — Closed commercial. `FACT` The only Cognition-adjacent open source relevant here is the *third-party* `AsyncFuncAI/deepwiki-open`, which is not Cognition's and confers no rights over DeepWiki. No Cognition source is available to read a `LICENSE` from; reuse is impossible.

**Deployment options** (https://docs.devin.ai/enterprise/deployment/overview) — two models:
1. *Enterprise Cloud*: Brain and Devbox both in "Cognition's secure, multi-tenant cloud"; public internet or IP allowlist; "each Devin session runs on its own isolated machine".
2. *Customer Dedicated*: Brain stays in Cognition Cloud; Devbox runs in a "customer-isolated single-tenant VPC"; connectivity via AWS PrivateLink or IPSec tunnel; OpenVPN supported.

`INFERENCE`: there is **no fully self-hosted / air-gapped option** — the Brain (orchestration + model calls) always remains with Cognition. Contrast GitLab Duo Self-Hosted, where inference data does not leave the customer network.

**Training on customer code** — `FACT` Default **on** for free and paid; opt-out via Data Controls; Enterprise requires express prior written consent. The Knowledge feature allows workflow-specific improvement without general model training (https://docs.devin.ai/admin/security).

**Retention** — `FACT` "Cognition only retains data processed through Devin for the duration of the relationship with a given Customer, unless otherwise specified." Feedback/interaction data retention is decided case-by-case (same URL).

**Compliance** — `FACT` SOC 2 Type II, obtained March 2024 (same URL). `UNVERIFIED`: ISO 27001, FedRAMP, data residency regions, subprocessor list, LLM vendors — none stated; defers to https://trust.cognition.ai/ (not fetched).

**Auth model** — `UNVERIFIED`. Git-platform app installation is implied by GitHub/GitLab support but the token scopes and org-consent model are not documented in fetched pages.

**Prompt-injection surface** — `INFERENCE` (rests on the documented context sources): Devin Review ingests repo-resident instruction files (`AGENTS.md`, `.cursorrules`, `CONTRIBUTING.md`) and admin-configured globs as *instructions*. On a public repo or any repo accepting outside PRs, a PR that adds or edits `AGENTS.md` is an instruction-injection vector into the reviewer of that same PR. `UNVERIFIED`: whether Devin Review reads instruction files from the base branch or the head branch — this distinction determines whether the vector is live. Would be verified by opening a test PR that modifies `AGENTS.md`.

## 7. Ideas to adopt or avoid

### Adopt

- **`.devin/wiki.json` as the pattern for generated-artifact control.** Specera should take the same shape: a committed config that names the pages/sections the generator must produce and supplies human notes, so generated architecture docs are reviewable, diffable, and reproducible instead of being a black-box render. Commit-triggered regeneration comes free with it.
- **Source-linked diagrams as the unit of architecture evidence.** DeepWiki proves teams accept a generated diagram when every node links to the file that justifies it. Specera should make that link the *stored edge* (architecture element → file → commit), which is the durable artifact DeepWiki renders but does not appear to persist as queryable traceability.
- **Logical diff grouping and code-movement detection.** Devin Review groups related changes and identifies moved/copied blocks rather than presenting alphabetical file order. For Specera's requirement→code mapping, move-detection is what prevents a pure refactor from being scored as unimplemented requirement drift.
- **CWE tags on security findings inside review.** Specera needs a stable taxonomy key to join a finding to a control/requirement; CWE is the cheapest correct choice and Devin Review already normalises to it.
- **Expose the knowledge index over MCP.** DeepWiki MCP is how Cognition gets its wiki into other agents' contexts. Specera's traceability graph should be MCP-addressable from day one for the same reason.

### Avoid

- **Training on customer code by default.** This is Cognition's most exploitable weakness. Specera should make "we never train on your code" a contractual default, not a settings toggle.
- **Generating a wiki with no staleness signal.** A wiki that cannot say "this page was generated at commit `abc123`, HEAD is 400 commits ahead" is decoration. Specera must stamp and surface index provenance per artifact.
- **Separating the knowledge index from the review path.** Cognition's own review docs never reference DeepWiki. If Specera builds an architecture graph and then reviews PRs without consulting it, it has built two products that don't reinforce each other.
- **Billing the review layer outside the admin's spend controls.** Review ACUs escaping per-org limits is a procurement objection Specera should not replicate.

## 8. Build, borrow, buy, integrate, or reject

**Reject as a dependency; borrow the DeepWiki *pattern*.** Closed source, so nothing is literally borrowable; and the default-on training policy plus the absence of a fully air-gapped deployment make Devin unusable as a subprocessor for the regulated customers Specera targets. But DeepWiki is the strongest public evidence that Specera's architecture/knowledge node is buildable and valued, and its two mechanical ideas — a committed generation config and source-linked diagrams — should be reimplemented independently (the open-source `deepwiki-open` is a separate evaluation, covered elsewhere in this spike). Optionally consume DeepWiki MCP read-only for public-OSS dependency understanding, where the training-policy objection does not apply.

## 9. Evidence

No repository — closed commercial service, no commit hash available.

URLs fetched 2026-08-04:
- https://docs.devin.ai/ — product surfaces: web app, CLI, shell/IDE/browser tools, Slack + Microsoft Teams integrations
- https://docs.devin.ai/work-with-devin/deepwiki — automatic indexing, architecture diagrams + source links, `.devin/wiki.json` steering and regeneration, public vs private repo split, DeepWiki MCP, no refresh schedule documented
- https://docs.devin.ai/work-with-devin/devin-review — instruction-file context, triggers, logical diff grouping, code-movement detection, severity-scored bugs, CWE security findings, platform matrix (GitHub/GitLab yes; Bitbucket/Azure DevOps no), **"does not block merges"**, ACU sizing XS–XL, review ACUs tracked at enterprise level
- https://docs.devin.ai/admin/security — **training on by default for free/paid**, opt-out via Data Controls, Enterprise express written consent, SOC 2 Type II (March 2024), retention for duration of relationship, defers to trust.cognition.ai
- https://docs.devin.ai/enterprise/deployment/overview — Enterprise Cloud (multi-tenant, Brain+Devbox at Cognition) vs Customer Dedicated (Brain at Cognition, Devbox in single-tenant customer VPC, AWS PrivateLink/IPSec)
- https://deepwiki.com/ — public index, "Deep Research for GitHub", "Add repo", no pricing or indexing detail on page
- https://cognition.ai/pricing → 301 → https://cognition.com/pricing — **both returned HTTP 404**; pricing therefore unverified

Search-derived, used only for `VENDOR CLAIM`/`UNVERIFIED` labels: ACU ≈ 15 minutes of active work and the Core/Team/Enterprise price points (secondary aggregator sites); DeepWiki launch 2025-04-27 vs deepwiki-open 2025-04-30; https://github.com/AsyncFuncAI/deepwiki-open README self-description as an independent implementation attempt.

Not verified, listed for follow-up: https://trust.cognition.ai/ (ISO, residency, subprocessors), live pricing page, DeepWiki page limits, whether Devin Review reads instruction files from base or head branch, any Jira/Linear integration.
