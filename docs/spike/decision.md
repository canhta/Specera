# Decision

**Two verdicts, against two different targets.**

| Target | Verdict | Where |
|---|---|---|
| Evidence / gate / compliance platform (Concepts 1–3) | **NO-GO** | §1–§5, rounds 1–2 |
| **SDLC knowledge graph, open source** (re-specified by sponsor after round 2) | **CONDITIONAL GO** | §7, round 3 |

Date 2026-08-04. Coordinator, on the evidence below. All three permitted rounds
were used.

`INFERENCE` The two verdicts are not in tension. Rounds 1–2 tested a product that
sells *assurance* and found the sellable claims already sold and the unsold claim
untruthful. Round 3 tested a different product that provides *a queryable graph*
and found the space genuinely unoccupied. The no-go below stands against what it
tested and should not be cited against the round-3 target.

## 1. The decision

Do not build the eleven-stage SDLC platform. Do not build any of the three
concepts at the scope proposed.

`INFERENCE` The strongest surviving idea — a customer-run merge gate over
requirement↔test evidence — is a feature, not a company. It should be recorded
and revisited only if one of the reopening conditions in §5 becomes true.

## 2. What decided it

Three findings, in descending order of weight. Each was **measured or verified**,
not argued.

### 2.1 The last differentiator is already a shipping product

`FACT` Tricentis **Vera**, integrated with qTest and Jira, ships 21 CFR Part 11
electronic signatures, a centralised review-and-approval portal, record locking,
auditable electronic records, and pre- and post-execution approvals for automated
tests (https://www.tricentis.com/products/digital-validation-vera;
https://docs.tricentis.com/qtest-saas/content/integrations/vera/using_qtest_test_cases_in_vera.htm
— both HTTP 200, coordinator-verified 2026-08-04).

`INFERENCE` This is decisive because it is precisely the claim
[`evaluation.md`](evaluation.md) §5 identified as the one carrying the price —
tamper-evident attribution — sold to precisely the regulated buyer that same
section identified as the only plausible one, inside Jira, today. The round-2
thresholds did not anticipate it, which is a limitation of the thresholds rather
than a reason to discount the finding.

**Correction, post-decision recheck**
([`.spike/recheck-vera.md`](../../.spike/recheck-vera.md)): the paragraph above
*understated* Vera. `FACT` Vera hashes as well as signs — its architecture spec
documents a Signatures module that "Applies 21 CFR Part 11 complaint signature
and hash" and a Verification module that verifies "records and signatures against
record and signature hash", and its Records Management Policy defines data fields
to be hashed. `FACT` Approved Vera records are Read-Only / Delete Denied / Move
Denied, deletion is confined to the first workflow state, and a revision
increments a new revision rather than overwriting — so the mutability weakness
described for Xray in §2.2 does **not** apply to Vera.

Two limits remain, and they are what the reopening question in §5 was actually
about. `UNVERIFIED` The only documented verification path is **admin-only inside
Tricentis' own portal** — a scheduled scan with a "Re-verify" button; no
algorithm, key custody, or published verification procedure appears anywhere in
the doc set, and absence from documentation is not proof of absence. `FACT`
Export carries no cryptographic material: the Record Detail Report is
print/save-to-PDF, and the qTest-side export is status metadata only. `FACT` The
signature binds to **record identifiers and versions — never to a build**: qTest
Version ID, Test Case Version, Execution Log Name, Jira fields, and a
Vera-managed integer `Revision`. No commit SHA, build number, or artifact digest
appears in any documented field.

### 2.2 The residue after Xray is two items, and both are weak

`FACT` Xray already ships four of the five steps of the surviving concept:
`@Requirement("KEY-123")` as a free EPL-2.0 JUnit annotation
(`Xray-App/xray-junit-extensions`, pushed 2026-04-15), JUnit XML import from CI, a
`Revision` field, and requirement coverage computed from executed runs.

Round 2 tested whether Xray's versions were weak enough to leave room. The
literal reject-triggers did **not** fire — `FACT` `Revision` is an unvalidated
free-text Jira custom field, coverage analysis scopes are Latest / Version / Test
Plan with no by-commit scope, and no merge gate exists in Xray, Zephyr Scale, or
qTest (`gh api orgs/Xray-App/repos` → 42 repos, zero Checks/App/Action
integration). So a gap is real.

But two of the four claimed differentiators were eliminated in the same test:
`FACT` retention is customer-determined with no vendor TTL and history is fully
mutable (statuses manually overridable, bulk delete on test runs), so "we retain
longer" is not a differentiator; and §2.1 eliminates tamper-evidence.

`INFERENCE` What remains is a customer-run merge-gate CLI over a competitor's
API. That is a thin, copyable product whose main asset is an integration with the
incumbent it competes against.

### 2.3 The evidence key does not survive merge

`FACT` Round 2 settled round 1's contested number properly, by ancestry test over
**1,160 merged PRs across 18 repositories** (0 unknown SHAs, 0 rate-limit
failures): pooled head-SHA survival **19.83%**, mean-of-repos 23.83%, **median
repo 2.0%**, 8 of 18 repos at exactly 0%, and **15 of 18 losing the majority** of
head SHAs to squash or rebase. Method validated against merge-parent counts
(repomix: 2 parents, survives; potpie: 1 parent, orphaned).

This refutes the coordinator's own weaker 6/19 proxy and substantially confirms
the red team's 13/19. `INFERENCE` The design's chosen key — `(work item key,
commit SHA)` — is orphaned for four out of five merged pull requests in this
corpus. A tree-digest fallback exists but was never designed, costed, or tested.

### 2.4 Supporting findings

- `FACT` The substrate is thinner than the proposal required. Median test-touch
  32–34% across 19 repositories with **9–10 of 19 below the blue team's own
  stated ≥35% threshold** ([`.spike/verification-coordinator.md`](../../.spike/verification-coordinator.md)).
  The blue team failed a threshold it set itself, by sampling the three
  highest-scoring repos in the corpus.
- `FACT` The core claim is unprovable. No design here or in any competitor can
  show that a passing test exercises the criterion it claims;
  `def test_ac2(): assert True` plus an annotation yields a valid signed green
  gate ([`security.md`](security.md)).
- `FACT` 0 of 19 repositories contain an ADR **or** configure a free architecture
  linter — measured absence of demand, which killed Concept 2 more decisively
  than its own falsification test would have.
- `FACT` Every incumbent AI reviewer is constitutionally advisory, and the
  category ships findings at ~33% precision independently measured
  ([`comparison.md`](comparison.md) §3).

## 3. What is explicitly *not* the reason

`INFERENCE` Stated because these are the plausible-sounding wrong reasons:

- **Not** "the incumbents are too big." A real gap exists — no test-management
  vendor ships a merge gate, and Rovo's detection-not-evidence asymmetry is
  genuine and explainable by Atlassian's own constraints.
- **Not** "the technology is infeasible." Most of it is straightforwardly
  buildable; [`roadmap.md`](roadmap.md) phase 1 is a real plan.
- **Not** red-team pessimism. The red team's headline number (13/19) was carried
  as `UNVERIFIED` until round 2 tested it, and the coordinator's competing number
  was the one refuted.

The reason is narrower and harder: **the parts that are defensible are already
sold by someone, and the part that is unsold cannot be claimed truthfully.**

## 4. What survives and should be kept

`INFERENCE` The research has durable value independent of the verdict:

- The **competitor corpus** ([`competitors/`](competitors/index.md)) — 29 files,
  source-level, with licence verdicts. Reusable for any adjacent decision.
- **Licence findings** that constrain any future build: GitNexus is PolyForm
  Noncommercial, stakgraph has no licence, sourcebot is FSL, bloop's pre-2024-04
  history contains a proprietary tree ([`inventory.md`](inventory.md)).
- **Two unowned mechanisms**, cheap and still unoccupied: per-edge confidence that
  is actually *filtered at query time* (no engine does this), and artifacts keyed
  by the commit they describe (no tool does this).
- The **supply-chain finding** ([`.spike/findings-supply-chain.md`](../../.spike/findings-supply-chain.md)) —
  first-hand evidence that cloning repositories surfaced agent-directive files
  into this spike's own coordinator. Relevant to any product ingesting customer
  repositories.
- `withmartian/code-review-benchmark` (MIT) as an independent evaluation harness.

## 5. What would reopen this

Both questions left open by round 2 have now been run. **The verdict is
unchanged, but for a more precise reason than §2 originally gave.**

**Question 2 — head-SHA survival — is closed. Not met.**
[`.spike/recheck-sha-survival.md`](../../.spike/recheck-sha-survival.md): a more
mature reference class (large corporate-operated OSS: Kubernetes, Spring Boot,
VS Code, Elasticsearch, Grafana, Kafka, Angular, React, Terraform) gives `FACT`
**25.0% pooled survival, median repo 0%**, against 19.83% / 2.0% in the original
corpus — the same order of magnitude, with a *worse* median. `INFERENCE` The
distribution is bimodal in both corpora: merge-commit shops preserve nearly
everything, everyone else preserves almost nothing. A product cannot be tuned to
a typical customer when the outcome is set by a merge-strategy toggle the vendor
does not control. `FACT` `golang/go` returned zero merged GitHub PRs — it reviews
via Gerrit, so even the GitHub-PR substrate is an adoption constraint.

**Question 1 — Vera — reopens narrowly, and the reopening is smaller than it
looks.** Per §2.1 as corrected: Vera hashes, verifies, and locks records, but its
verification is vendor-internal and undocumented, its export carries no
cryptographic material, and — the one `FACT`-grade gap — **its signature never
binds to a build, commit, or artifact digest.**

`INFERENCE` **The two answers converge, and the convergence is the real finding.**
The single gap Vera leaves is binding evidence to *what was actually built*. The
obvious way to fill it — key evidence to a commit SHA — is precisely what
question 2 shows fails in three of four repositories. The design that survives
both results is therefore neither of the ones proposed: bind evidence to a
**content-addressed artifact digest**, which is immune to squash and rebase
because it does not depend on commit identity at all.

`INFERENCE` That is a genuinely unoccupied mechanism. It is also, on the recheck
agent's own assessment and mine, **a feature rather than a company** — which was
§2.1's original objection and remains unanswered. Its natural commercial form is
sold *to or with* a test-management vendor, not against one.

**The no-go therefore stands**, narrowed to this: do not build the platform, and
do not build a Vera/Xray competitor. Record artifact-digest-bound evidence as the
one mechanism worth revisiting, under the structural condition below.

A third, structural condition: `INFERENCE` the one asymmetry no single vendor can
close by shipping a feature is **cross-tracker, cross-repository evidence** —
Atlassian sees Jira, GitHub sees code, neither sees both. If a buyer is found who
pays for that specifically, the analysis changes. Nothing in this spike found one.

## 6. Method note

`FACT` The loop worked as designed and its most valuable outputs were the
self-corrections: the blue team's designated critical fact was falsified; the
coordinator's own kill criterion was defective and was amended on the record
([`plan.md`](plan.md)); the coordinator's SHA measurement was refuted by a better
test; and a coordinator hypothesis about artifact grounding was refuted by an
agent that checked instead of agreeing.

`INFERENCE` A spike that produces a no-go in two rounds, for reasons that can be
checked by a reader who disagrees, is a cheaper outcome than a build that
discovers §2.1 in month nine.

---

## 7. Round 3 — the re-specified target: CONDITIONAL GO

After round 2 the sponsor re-specified the target as **"Graphify, but for the
whole SDLC"** — an open-source, single-source-of-truth knowledge graph and
governance layer over Jira, Confluence, GitHub, Gherkin, Grafana and MCP, for
agents and humans. `INFERENCE` Rounds 1–2 never evaluated this. All three
concepts drifted toward evidence and gates; the graph-as-product framing was a
coordinator framing error, recorded here rather than quietly fixed.

Round 3 measured the only question that decides it: **which non-code edges can be
derived deterministically?** Full measurements — 39,703 commits, 4,491 merged PRs,
3,252 issues, 1,917 docs, 4,596 test files, 19 repos plus one live Jira — in
[`.spike/round3-sdlc-graph.md`](../../.spike/round3-sdlc-graph.md). The edge
classification is reproduced in [`sdlc-model.md`](sdlc-model.md) §4.

### 7.1 What decided it

`FACT` **The space is unoccupied.** Graphify ships **no SDLC graph at all**: zero
Jira references in its tree, `prs.py` contains no `add_edge` call, and the node
vocabulary is still six file types. Its "codebases, documentation, and Jira"
positioning is not in the open-source product. Rovo's Teamwork Graph is
Atlassian's equivalent but is EAP, may not be deployed to production or
distributed, retains 90 days, and returned only `AtlassianUser` edges under
first-hand test.

`FACT` **The failure mode is coverage, not precision.** EXTRACTED:INFERRED is
**72:28** across the whole graph. Because provenance tagging permits bailing out
rather than guessing, the result is *sparse but true* — it does **not** inherit
the ~33% precision trap in [`comparison.md`](comparison.md) §3. This is the single
most important difference between this target and the rejected ones.

`FACT` **Round 2's SHA problem does not apply here.** Merge commits resolve at
**99.5%**, against 19.83% head-SHA survival. Keying on the merge commit rather
than the head SHA rescues the design.

### 7.2 The condition

`FACT` The intent tier measured **0:100** — ADR→code, requirement→code,
requirement→test, incident→release and PRD→work item all have zero left-hand
nodes across 19 repositories.

`INFERENCE` **That number is about the corpus, not the mechanism**, and the
coordinator disagrees with the round-3 agent's reading of it. Open-source repos do
not write PRDs, ADRs or acceptance criteria, and do not use Jira. The same agent
measured a live Jira at **89% deterministic** issue→epic edges. The honest
statement is therefore conditional: **the graph's value depends on the
organisation actually producing intent artifacts.** Where they exist, the chain is
derivable; where they do not, there is nothing to connect and the product degrades
to git/tracker plumbing that GitHub and Jira already render.

`INFERENCE` **Gherkin is the load-bearing exception and the strongest element of
the sponsor's specification.** It is the only intent artifact with a grammar:
acceptance criteria, ADRs and PRDs are prose and can only be `INFERRED`, whereas
`Feature` / `Scenario` / `Given-When-Then` parses to a real AST and is
`EXTRACTED`. The chain `Scenario → step definition → test → run → commit → merge
commit → release` is deterministic almost end to end. Only `AC → Scenario`
requires a human or a model — and that step happens once at authoring time, not
on every run, which makes it the correct place for a human gate.

### 7.3 Verdict

**Conditional go**, on the target as re-specified, open source, with the
conditions: build the graph as source of truth for **edges** rather than nodes
(nodes stay owned by Jira, GitHub and Grafana, mirrored with provenance and TTL);
tag every edge `EXTRACTED` / `INFERRED` / `AMBIGUOUS` and **filter to
high-confidence at query time by default**, which no engine in this spike does;
and key artifacts to the merge commit.

`INFERENCE` **Amended 2026-08-04.** This section originally ended "and sequence
Gherkin first, because it is the only mechanically parseable bridge from intent to
execution." Gherkin's grammar property is real and still holds, but `FACT` 0 of 19
clones contain any `.feature` file, so sequencing the product on it would build on
a substrate that has never been observed. Connectors are now ordered by how
reliably the source data exists — code (100%) first, Gherkin as connector M5 — and
the platform itself is complete before any connector rather than growing with them.

Architecture: [`product-proposal.md`](product-proposal.md). Stack:
[`stack.md`](stack.md). Build plan and tracking: [`../roadmap.md`](../roadmap.md).
