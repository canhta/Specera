# Raw evidence: Greptile (research date 2026-08-04)

Preserved by the coordinator against agent loss. **Input for
`docs/spike/competitors/services/greptile.md`** — not a deliverable itself.
Legal entity: every greptile.com page footer reads `© 2026 Tabnam, Inc.`

## The finding that matters most to the whole spike

An **independent, open-source, MIT-licensed code-review benchmark exists**:
`withmartian/code-review-benchmark` (https://github.com/withmartian/code-review-benchmark,
site https://codereview.withmartian.com). Offline set = 50 PRs from Sentry /
Grafana / Cal.com / Discourse / Keycloak with human-curated golden comments;
computes **precision and recall**. Its README states the motivation directly:
"Without shared evals for these tools, every company grades its own homework."

Micro-averaged from raw `evaluations.json` (judge `claude-opus-4-5`), computed by
the research agent, **not Martian's official leaderboard numbers**:

| Tool | F1 | Precision | Recall | tp/fp/fn |
|---|---|---|---|---|
| cubic-v2 | 61.8 | 56.3 | 68.6 | 94/73/43 |
| augment | 53.5 | 47.5 | 61.3 | 84/93/53 |
| bugbot | 45.5 | 47.2 | 43.8 | 60/67/77 |
| greptile-v4-1 | 44.0 | 40.5 | 48.2 | 66/97/71 |
| greptile-v4 | 41.8 | 33.1 | 56.9 | 78/158/59 |
| copilot | 37.0 | 28.3 | 53.3 | 73/185/64 |
| coderabbit | 35.2 | 25.7 | 56.2 | 77/223/60 |
| graphite | 16.1 | 100.0 | 8.8 | 12/0/125 |

Source: https://raw.githubusercontent.com/withmartian/code-review-benchmark/main/offline/results/anthropic_claude-opus-4-5-20251101/evaluations.json

Caveats to carry forward: the micro-average is the agent's computation, not
Martian's published figure; third-party write-ups claiming CodeRabbit tops the
leaderboard at ~51% F1 do not match this file and probably refer to the online
set or another judge — do not merge the two; and this corpus shares its five
repos with Greptile's own benchmark, so the datasets are related, not
independent samples.

**Vendor benchmark vs independent judging.** Greptile publishes
(https://www.greptile.com/benchmarks) "Greptile 82% | Bugbot 58% | Copilot 54% |
CodeRabbit 44% | Graphite 6%" — with this verbatim admission:

> "Scoring considered only detection of the original bug; **false positives**,
> style suggestions, and unrelated comments **did not affect the catch rate**."

Conducted July 2025, predating v3 and v4, vendor-chosen dataset, vendor-run.
Independent judging of the same corpus puts v4 at ~57% recall and ~33%
precision. Greptile has **never published a false-positive rate**, despite "far
lower false positive rate" being the v4 headline claim
(https://www.greptile.com/blog/greptile-v4); every published metric is an
engagement proxy (upvote ratio, action rate, addressed rate). Their own v4
figure "% of comments addressed = 43%" implies 57% of comments are not acted on.

**Why this matters beyond Greptile:** the entire AI-code-review category is
measured on recall and engagement, by vendors, on their own datasets. Precision
is the unowned metric. This is direct evidence for the spike's evaluation design
and a candidate differentiator — and the benchmark is MIT, so Specera can run it.

## Retrieval architecture — corrects a common misreading

Greptile does **not** claim to avoid embeddings. It embeds *generated docstrings*
rather than raw code, plus a graph, plus agentic search. Founders, Launch HN
2024-03-05 (https://news.ycombinator.com/item?id=39604961), verbatim:

> "(1) Instead of directly embedding code, we parse the AST of the codebase,
> recursively generate docstrings for each node in the tree, and then embed the
> docstrings. (2) Alongside vector similarity search and keyword search, we do
> 'agentic search' where an agent reviews the relevance of the search results,
> and scans the source code to follow references."

Measured justification (https://www.greptile.com/blog/semantic-codebase-search,
2025-04-15): query↔code similarity 0.7280 vs query↔description 0.8152 (+12%);
per-function chunking 0.768347 beats whole-file 0.718032.

Parser: **no public statement** of tree-sitter/LSP/ctags. Strongest artifact
evidence is their GitHub org carrying forks of **SCIP indexers**
(`greptileai/scip-typescript`, `-python`, `-go`, `-java`, all last pushed
2024-08-01) — inference from artifacts, not a vendor claim, and possibly
abandoned.

2026 architecture has shifted to a generated "knowledge base"
(https://www.greptile.com/blog/automating-code-validation, 2026-07-10): "a
monorepo for a medium-sized company could yield hundreds of pages of content."
Multi-model router; self-host docs require Smart + Fast + Embeddings models and
**PostgreSQL with pgvector** where "embeddings are the largest component"
(https://www.greptile.com/docs/system-architecture). First index ~1–2 hours;
review latency ~3 minutes; reads up to 7 related repos per review.

## SDLC reach — further than most competitors

- **Jira/Linear read-only**: ticket description and acceptance criteria become
  review context; "Greptile never writes to Jira"
  (https://www.greptile.com/docs/jira-integration).
- **TREX** (Test/Run/Execute, public beta 2026-06-15): writes targeted tests for
  the PR and **runs them in an isolated sandbox**, attaching logs/screenshots/
  traces to failed PR comments; 3 credits vs 1 (https://www.greptile.com/blog/trex).
  This is runtime evidence, not LLM assertion — the closest competitor behaviour
  to Specera's deterministic-verification thesis.
- **Security**: Opengrep rule-based scanning + SCA/CVE + AI chained-exploit
  detection (https://www.greptile.com/security-check).
- **No merge blocking found.** The opposite ships: **auto-approve** on a clean
  5/5 review, excluded for auth, secrets, billing, DB migrations, infra/CI, and
  public APIs (https://www.greptile.com/docs/code-review/auto-approve-prs).
- **Incidents/monitoring: no public information found.** Release notes: not a
  shipped product.
- Feedback learning: reads first and last commit of every PR to see which
  comments were addressed; suppresses a comment type after being ignored 3+
  times, except security/memory-leak/infinite-loop/null-deref/missing-validation
  (https://www.greptile.com/docs/how-greptile-works/nitpicks).

Strategic posture worth noting (https://www.greptile.com/blog/ai-code-review-bubble):
> "we have never shipped codegen features. We don't write code; an auditor
> doesn't prepare the books… a student doesn't grade their own essays."

## Enterprise blockers

- **Pricing**: $30/active developer/month including 50 credits, then **$1 per
  additional review**; 1 credit = 1 standard review, 3 = 1 TREX review; billed
  per completed review to the PR author, not pooled
  (https://www.greptile.com/docs/code-review-bot/billing-seats). Changed
  2026-03-05 from flat to base+usage.
- **Customer code trains models by default, opt-out** — de-identified data used
  to "train and improve artificial intelligence algorithms and models"; Greptile
  "solely and exclusively owns" the resulting learnings. Self-hosted is exempt
  (https://www.greptile.com/security).
- **Code is stored** on an encrypted filesystem "until access is revoked in
  GitHub or GitLab" — a reversal of their 2024 Launch HN claim not to store code.
- **Compliance contradiction**: the security page (updated January 2026) claims
  **only SOC 2 Type II** and never mentions ISO 27001, GDPR, or HIPAA; the
  Enterprise page FAQ claims "SOC 2 Type II, HIPAA and GDPR compliant"
  (https://www.greptile.com/enterprise). Two live pages disagree. Trust Center
  (https://trust.greptile.com) is a Vanta SPA whose contents could not be
  extracted — the largest verification gap in this research.
- **No managed data residency**: AWS + Azure, no region list published.
  Residency effectively requires self-host, which needs a paid Enterprise
  licence. Self-host is genuinely deep though: air-gapped, Docker Compose or
  K8s (Helm `greptileai/akupara`), BYO-LLM, **Perforce** support, SSO via
  BoxyHQ Jackson, max 30-day version lag.
- **No ZDR statement** with OpenAI/Anthropic found — must be demanded in the DPA.

## Company status

YC W24, active, ~35 people. Seed $4.1M (2024-06-09); Series A $25M led by
Benchmark (2025-09-23); ~$180M valuation per TechCrunch 2025-07-18 (reported as
in-talks, anonymously sourced). Self-reported customer counts are internally
inconsistent on pages live simultaneously: "9,000+ teams" (homepage/enterprise)
vs "22,000 engineering teams" (blog, 2026-06-04).

## Independent criticism

Substantive negative HN report (https://news.ycombinator.com/item?id=46777079,
2026-01-27): "pretty much pure noise" over 3 PRs; flagged "python 3.14 does not
exist yet" as a logic error; agreed "You're absolutely right" to a correction it
had itself invented. Mixed corroboration elsewhere — one user found it "without
a lot of time wasting nonsense/false positives"
(https://news.ycombinator.com/item?id=48550125), another expected "the false
positive rate will be so high that it won't be useful"
(https://news.ycombinator.com/item?id=47733209).

Pricing backlash: https://greptile-fail.vercel.app/ — **anonymous single-author
advocacy site, not neutral journalism**, but quotes dated attributable X posts
and the pricing facts check out. Named public cancellations over per-review
billing at agent-scale PR volume (one user citing 571 PRs in 30 days → $500+/mo),
OSS-program billing failures, and no in-app cancel button. Partial corroboration:
Greptile shipped Flex Usage Limits on 2026-04-30, the day criticism peaked.

## Sources excluded as AI-content-farm / SEO spam

Not cited anywhere: dev.to/jovan_chan_*, weavai.app, aicoolies.com,
surmado.com, medium.com/@lewis_75321, tech-insider.org, particula.tech,
levelop.dev, grokipedia.com, highperformr.ai, startupintros.com, leadiq.com.
Tracxn's $45.5M total conflicts with primary sources — treat ~$30M as defensible.
Vendor-owned comparison pages (augmentcode.com/tools/*, coderabbit.ai/blog/*,
cubic.dev/blog/*, greptile.com/greptile-vs-*) are sales collateral, not evidence.
